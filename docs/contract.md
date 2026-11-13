# Dish ↔ Satellite contract: client notes (iOS)

The protocol contract (REST surface, UDP streams, crypto, liveness,
identity) lives in ONE place: **`satellite/docs/contract.md`** in the
[TinkerNorth/satellite](https://github.com/TinkerNorth/satellite) repo. This
client offers protocol 4 and still speaks 1, as the fleet does, with control
on `:9443` (HTTPS REST) and data on `:9876` (encrypted UDP); this file
records only the iOS-side mapping. When code and contract disagree, the
contract wins.

## Where the contract lands in this app

The pure protocol layer is the `DishCore` target (Foundation and CryptoKit
only; `ImportBoundariesTests` lists the allowlist): the constants, the
codecs, the session crypto and the policy reducers, ported from dish-mac with
its file, type and test names and pinned by the fleet's cross-repo vectors
(`Tests/DishCoreTests/SessionCryptoVectorTests.swift`, `TestVectors.swift`).
The imperative shell is `Sources/DishEngine/Network`, which owns the socket,
the URL sessions and the stores, behind seams the tests replace. Every row
names its files; what is not built is in [`Tests/PARITY.md`](../Tests/PARITY.md).

| Contract concept | dish-ios home |
|---|---|
| Ports (9443 control, 9876 data) and the protocol constants (version 4, the opcodes, the caps, the extended-button bits, the cadences) | `Sources/DishCore/ProtocolConstants.swift`; the defaults a discovery result falls back to in `Sources/DishEngine/Models/SatelliteModels.swift`; `ProtocolConstantsTests` |
| HKDF session key, `hmacProof`, packet AEAD (direction nonce, AAD = token) | `Sources/DishCore/Wire/SessionCrypto.swift` (cross-repo vectors: `SessionCryptoVectorTests`) |
| Packet framing (`token(4)‖counter(4)` header, `msgType‖msgLen‖payload` inner frame) | `Sources/DishCore/Wire/PacketCodec.swift` |
| Stream payloads up (input 13, or 17 from version 4; motion 17, battery 3, touchpad 16, the 0x000C POINTER frame from version 2) and down (heartbeat ack, rumble, light bar, trigger effects, player LEDs) | `Sources/DishCore/Wire/Encoders.swift`, `FeedbackCommands.swift`; the shape by the settled version in `SatelliteClient.sendTouchpad` and `SatelliteClient.sendReport` (`Sources/DishEngine/Network/SatelliteClient+Streams.swift`) |
| INPUT 0x0001's extended-buttons word (version 4, 17 bytes; SDL's names, `extButton*`) and the `extendedButtons` cap, a claim that the pad sources the word | `GamepadReport.extButtons` and `Encoders.writeInputPayload` in `Sources/DishCore/Wire/`; an Xbox Elite's paddles into the word in `Sources/DishEngine/Input/GameControllerInput+Paddles.swift`; the claim from `ControllerCapabilities.hasExtendedButtons` in `Sources/DishEngine/Network/DescriptorCaps.swift` |
| Which battery a MSG_BATTERY carries: the lower of the pad's own and the device's (the fleet's client rule; the contract fixes only the payload) | `Sources/DishCore/Reducers/BatteryRouting.swift` (`routeBattery`), applied by `forwardBattery` in `Sources/DishEngine/Input/GameControllerInput+Battery.swift` over the scene's `DeviceBattery`; the same reading feeds a Moonlight host's CONTROLLER_BATTERY; `BatteryRoutingTests` |
| Controller audio frames (0x0012 to 0x0015) | `Sources/DishCore/Wire/AudioFrames.swift`; the receive loop recognises and skips them, since iOS gives apps no pad audio |
| UDP data plane: the socket (`IP_TOS = 0xB8`, `SO_NOSIGPIPE`, 500 ms receive timeout), counters from 1 per direction, the replay guard, the send gate, the heartbeat, the receive thread | `Sources/DishEngine/Network/SatelliteClient.swift`, `SatelliteClient+IO.swift`, `SatelliteClient+Streams.swift`, `SendGate.swift`, `ReceiveHandlers.swift`; `SatelliteClient*Tests` |
| Per-session liveness (2 s heartbeat, the alive tick, the enriched-ack snapshot, close-reason surfacing) | `Sources/DishEngine/Network/WifiConnection.swift` |
| Close-notify (0x000F) reason → follow-up action | `Sources/DishCore/Reducers/CloseNotify.swift`, applied by `handleClose` in `WifiConnectionManager+Lifecycle.swift` |
| Reconnect backoff (1 s → 60 s cap) | `Sources/DishCore/Reducers/Backoff.swift`, armed by `scheduleRetry` in `WifiConnectionManager+Lifecycle.swift` |
| Latency readout (64-sample RTT window, p50 ÷ 2, single-in-flight ping) | `Sources/DishCore/Reducers/LatencyWindow.swift`, held by `SatelliteClient`, published by `WifiConnection.publishLatency` |
| Reconcile (epoch and bitmap drift → GET → adopt or re-PUT) and the `counterNeedsRepush` re-key threshold | `Sources/DishCore/Reducers/Reconcile.swift`; `runReconcile` in `WifiConnectionManager+Lifecycle.swift`, `rekeySession` in `WifiConnectionManager+Session.swift` |
| Wire DTOs (controller descriptor, session, controller and pair responses, host-feature grants) | `Sources/DishEngine/Network/RestModels.swift`; `RestModelsTests` |
| Authed REST routes (session PUT, GET, DELETE; per-slot PUT and DELETE; self-unpair) with `X-Device-Id` and `X-Hmac-Proof` | `Sources/DishEngine/Network/HTTPClient.swift` |
| REST error model (terminal 401 codes, 409, 503, transport) | `Sources/DishCore/Reducers/RestOutcome.swift`, read through `RestStamped.verdict` in `RestModels.swift` |
| Pairing paths A and B (`POST /api/pair`, the `GET /api/pair/status` poll), the outcome classification | `Sources/DishEngine/Network/PairingClient.swift`; the approval verdicts and the poll's next step in `Sources/DishCore/Reducers/ReversePairing.swift`; path A in `WifiConnectionManager+Pairing.swift`, path B in `WifiConnectionManager+Approval.swift`, the card's state in `PairingAttempts.swift`; `PairingClientClassifyTests`, `OperatorApprovalTests` |
| Session lifecycle: declarative PUT, HKDF key handoff, proactive re-key | `Sources/DishEngine/Network/WifiConnectionManager+Session.swift` |
| `controllers[]` with `ctrlIdx`: up to four pads per session on the lowest free index; the live per-slot converge of exactly the indices an edit changed | `Sources/DishCore/Reducers/SatelliteSlots.swift`; `SatelliteSlotTable.swift`, `WifiConnection+Slots.swift`, `WifiConnectionManager+Slots.swift` in `Sources/DishEngine/Network/` |
| Descriptor caps as promises (the hardware and the user's switch) and `touchpadMode` | `Sources/DishEngine/Network/DescriptorCaps.swift`; `DescriptorCapsTests` |
| Catalog version 2 (`emulates`, the feature slugs, `modes`) and the type a pick is emulated as; type 4 `dualsenseedge`, a `ps5` pad found only by its id, so no family's own pick lands on it | `Sources/DishEngine/Network/CatalogModels.swift`; `preferredControllerType` and `emulationCandidates` in `DescriptorCaps.swift`, read before the first session PUT |
| `GET /api/server/capabilities` | `Sources/DishEngine/Network/ServerCapabilities.swift`, cached by `fetchCapabilities` in `WifiConnectionManager+Session.swift`; `ServerCapabilitiesTests` |
| Versioning: the offer, the 409 range, the settled version that keys the frames | `Sources/DishCore/Reducers/ProtocolNegotiation.swift`, applied by `settleOffer` and `adoptGrant` in `WifiConnectionManager+Session.swift` |
| Connect and pair flows, terminal-401 key drop and the stale marker, forget → self-unpair | `Sources/DishEngine/Network/WifiConnectionManager.swift` and its extensions; `WifiConnectionManagerControlPlaneTests`, `IntegrationSessionLifecycleTests`, `IntegrationReconcilePolicyTests` |
| Identity: `mid:<machineId>` keying, legacy-ghost collapse, DHCP re-home | `Sources/DishEngine/Network/ConnectionStore.swift` (`UserDefaults`, under dish-mac's `wifi_list` and `deviceId` keys); `ConnectionStoreIdentityTests` |
| TOFU pinning (pin on first contact, abort the handshake on a mismatch) | the verdicts and the fingerprint in `Sources/DishCore/Reducers/Tofu.swift`; `Sources/DishEngine/Network/TofuTrustDelegate.swift`, composed by `WifiConnectionManager.makePinVerifier`; the pins in `CertPins.swift` (a JSON file in Application Support); `TofuPinningDelegateTests` |
| Pairing-key storage (Keychain; in memory for tests) | `Sources/DishEngine/Network/KeyStore.swift`; `KeyStoreTests` |
| Discovery: mDNS `_satellite._udp` and its TXT record (`udp`, `pair`, `http`, `mid`) | `Sources/DishEngine/Network/MdnsBrowser.swift` over `BonjourScan.swift`; the Local Network status from the browse in `LocalNetworkProbe.swift` and `BonjourLocalNetworkAccess` (`Sources/DishEngine/LocalNetwork/LocalNetworkAccess.swift`); `MdnsDiscoveryTests`, `BonjourScanTests`, `LocalNetworkProbeTests` |
| Discovery: the legacy UDP `:9879` beacon | not built: listening needs the multicast entitlement (`Tests/PARITY.md`, section 3) |
| Return paths to the pad bound to each index | `FeedbackRoutes` and `ReturnPathRouter` in `Sources/DishEngine/Input/ReturnPathRouter.swift`, installed on the client by `WifiConnection+ReturnPaths.swift` |
| The admin API (loopback `:9877`) | not applicable to the app: the satellite's operator surface. The loopback driver (`IntegrationLiveSatelliteE2ETests`, `scripts/e2e_local.sh`) reads it as the server's truth |

Test double: `Tests/DishEngineTests/Support/FakeSatellite/` is dish-mac's
in-process satellite, ported: REST over TLS with an identity imported from a
PKCS#12 fixture (two, so a pin taken from one instance is refused by the
next), a protocol range of 1...4 like the real one's, the UDP data plane with
its own CryptoKit crypto asserted against the same pinned vectors and INPUT
read by length (the extended-buttons word from 17 bytes, 0 below), and every
return path injectable. The control-plane,
data-plane, approval, hub, model and `Integration*` suites drive it.

## Client behaviours required by the contract

- **Declarative topology.** A bind carries the full descriptor; slots absent
  from the PUT are unplugged server-side. While live, single-slot changes
  ride `PUT /api/connections/{id}/controllers/{idx}` (and a pad that let go
  its `DELETE`), so the token never rotates for a toggle. Zero-controller
  sessions are valid.
- **Session key ≠ pairing key.** Every session PUT re-derives the key; the
  pairing key never reaches `SatelliteClient`. Counters restart at 1.
- **Terminal 401** drops the stored key, parks the row on "Needs pairing"
  and stops retrying; **terminal 409** keeps the key and says which end must
  update.
- **Proactive re-key** at `0xF0000000` on the same socket; a session that
  exhausts anyway goes silent, never wraps.
- **Close-notify**: `unpaired` is terminal, `replaced` stays down,
  `shutdown` and `kicked` re-enter the backoff.
- **Identity** by machine id; a satellite at a new address re-homes its row
  and takes its pin along.
- **TOFU**: a later mismatch aborts the handshake before any request bytes
  flow and surfaces as an identity change, not as unreachable.
- **Pairing**: no PIN-free path; both paths run at once from the card, and
  whichever lands first opens the session and stops the other. Forget
  self-unpairs (`DELETE /api/pair`) before the local key goes.
- **Backgrounding**: iOS suspends a backgrounded app, so the engine's
  `enteredBackground()` closes every session the graceful way and
  `enteredForeground()` reaches for the remembered satellites again, as
  `DishScene` calls them on the scene phase.

## Moonlight hosts: the other protocol

A Moonlight host (Sunshine, Apollo, Wolf) is not a satellite and speaks
nothing of the contract above: it speaks GameStream, learned from Wolf's
documentation and MIT source (`THIRD_PARTY.md`, sections 2b and 2c), and
Dish uses it for input only, as dish-mac does. The pure half is
`Sources/DishCore/Moonlight/`, pinned by Wolf's published vectors; the edges
are `Sources/DishEngine/Moonlight/`. What is not built is in
[`Tests/PARITY.md`](../Tests/PARITY.md).

| Moonlight concept | dish-ios home |
|---|---|
| Ports (HTTP 47989, HTTPS 47984, RTSP 48010, the control, video and audio ports the host names), the input and event types, the button bits, the capabilities and the controller types | `Sources/DishCore/Moonlight/MoonlightProtocol.swift`; `MoonlightProtocolTests` |
| `/serverinfo`, `/pair`, `/applist`, `/launch`, `/resume`, `/cancel` and their XML replies, whose verdict is the `status_code` in the body, not the status line | `MoonlightUrls.swift`, `MoonlightXml.swift`; `MoonlightUrlsTests`, `MoonlightXmlTests` |
| The five-phase PIN pairing: the AES key from the salt and the PIN, the challenges and the signed secrets, phase 5 over mutual TLS trusting the certificate phases 1 to 4 proved | `MoonlightPairing.swift`, `MoonlightPairingCrypto.swift` (CommonCrypto's AES-ECB), `MoonlightCertificate.swift`; the manager's `+Pairing`; `MoonlightPairingTests`, `MoonlightPairingCryptoTests`, `MoonlightManagerPairingTests` |
| The client identity: RSA-2048 and a self-signed `NVIDIA GameStream Client` certificate, minted once in the Keychain, presented on every mutual-TLS connection | `Sources/DishEngine/Moonlight/MoonlightIdentityStore.swift`, `MoonlightAsn1.swift`, `MoonlightHttpTransport.swift`; `MoonlightIdentityStoreTests`, `MoonlightHttpTransportTests` |
| The host's certificate: pinned on first use under `moonlight:<address>`, replaced by the one a pairing proves, a different one refused inside the handshake | `MoonlightGateway.swift` over `CertPins`; `MoonlightGatewayTests` |
| RTSP: OPTIONS, DESCRIBE, SETUP audio, video and control, ANNOUNCE and PLAY, one connection per message; the ports, the connect token and the ping payload read back | `MoonlightRtsp.swift`, `MoonlightRtspClient.swift`; `MoonlightRtspTests`, `MoonlightRtspClientTests` |
| ENet, the client subset the control stream needs: connect, reliable send and receive on one channel, acknowledgements, ping and disconnect | `Sources/DishCore/Moonlight/Enet/`; `EnetClientTests` |
| The control seal (AES-128-GCM, the IV from the sequence's low byte, the tag before the ciphertext) and the packets (CONTROLLER_MULTI, ARRIVAL, TOUCH, MOTION, BATTERY, the periodic ping, TERMINATION) | `MoonlightControlSeal.swift`, `MoonlightInput.swift`, `MoonlightControlSession.swift`; `MoonlightControlSealTests`, `MoonlightControlPacketTests`, `MoonlightInputTests`, `MoonlightControlSessionTests`, `MoonlightControlSessionLockTests` |
| The host's events (rumble, trigger rumble, a motion request, the RGB LED, termination) and where they land | `MoonlightEvent.swift`, `MoonlightFeedbackRouter.swift`; `MoonlightEventTests`, `MoonlightFeedbackRouterTests` |
| The media pings that keep the host's video and audio ports open | `MoonlightMediaPing.swift`, `MoonlightUdp.swift`; `MoonlightMediaPingTests`, `MoonlightUdpTests` |
| Pad numbers and the active mask, what an arrival declares, and the touch, motion and battery conversions | `MoonlightPadSlots.swift`, `MoonlightPadRules.swift`, `MoonlightPadTable.swift`, `MoonlightTelemetry.swift`; their tests, `MoonlightPadLinkTests` |
| The session's lifecycle: probe, launch or resume, RTSP, control, streaming, and each refusal | `MoonlightSessionMachine.swift` (`reduceMoonlightSession`, `moonlightConverge`); the manager's `+Session`; `MoonlightSessionMachineTests`, `MoonlightManagerSessionTests` |
| Discovery: mDNS `_nvstream._tcp`, and a host added by address | `MoonlightDiscovery.swift` over `BonjourScan`; the manager's `startDiscovery` and `addManualHost`; `MoonlightManagerTrustTests` |

The behaviours the hosts require:

- **One session per host**, owned by every binding that points at it: the
  first pad launches the app, a later one arrives on the live link, the last
  one leaving a live session hands the app back with `/cancel`. A drop or the
  host's own ending leaves the app alone, and a disconnect keeps it for the
  next session to resume.
- **The PIN is Dish's**: minted for each attempt, shown in the host's row,
  typed into the host's own page. Cancel, a forget and every refused phase
  write nothing.
- **Trust is told over mutual TLS only**: the plaintext `PairStatus` says
  nothing about this device, and a host that answers under another uniqueid
  is a host that was replaced.
- **Forget** cancels a live session's app while the pin still opens the
  connection, then drops the record, the bindings and the pin. The protocol
  has no unpair verb, so the host keeps its own record of this device.

Test double: `Tests/DishEngineTests/Moonlight/FakeMoonlightHost.swift` is
dish-mac's loopback host, ported: plain HTTP and mutual TLS with a PKCS#12
identity, the five phases answered by a reference host built from the same
primitives, an RTSP host that hands out its own ports, the media ports, and
a control port that opens every sealed packet. `IntegrationMoonlightFakeHostTests`
drives the real manager and sockets against it.
