# Dish ↔ Satellite contract: client notes (iOS)

The protocol contract (REST surface, UDP streams, crypto, liveness,
identity) lives in ONE place: **`satellite/docs/contract.md`** in the
[TinkerNorth/satellite](https://github.com/TinkerNorth/satellite) repo. This
client is meant to offer protocol 3, as the fleet does, with control on
`:9443` (HTTPS REST), data on `:9876` (encrypted UDP) and the legacy beacon on
`:9879`; this file will record only the iOS-side mapping. When code and
contract disagree, the contract wins.

## Where the contract lands in this app

**Today it lands in the pure core only.** The pure protocol layer is the
`DishCore` target (Foundation and CryptoKit only; `ImportBoundariesTests`
lists the allowlist): the constants, the codecs, the session crypto and the
policy reducers, ported from dish-mac with its file, type and test names and
pinned by the fleet's cross-repo vectors
(`Tests/DishCoreTests/SessionCryptoVectorTests.swift`, `TestVectors.swift`).
`DishEngine` opens no socket yet, and the app makes no network connection
(`PRIVACY.md`). A row that is "not yet" names the home it is planned to have,
so the wave that builds it fills the second column instead of inventing a
layout. The imperative shell will be `Sources/DishEngine/Network`, which owns sockets, the
URL session and the stores, behind seams the tests replace, as
`LocalNetworkAccess` is replaced today. Each row's gap is in
[`Tests/PARITY.md`](../Tests/PARITY.md).

| Contract concept | dish-ios home |
|---|---|
| Ports (9879 beacon, 9443 control, 9876 data) | `Sources/DishCore/ProtocolConstants.swift`, with the protocol version (3), the opcodes, the caps and the cadences; `ProtocolConstantsTests` |
| Identity (`deviceId`, the satellite's machine id) | not yet: `DishEngine/Network`, beside the connection store; the device's name is the one piece that exists, in `DevicePreferenceStore` (`device_name`) |
| Pairing, paths A and B (`POST /api/pair`, `GET /api/pair/status`), key rotation, delete | the approval verdicts and the poll's next step in `Sources/DishCore/Reducers/ReversePairing.swift`; not yet: `DishEngine/Network` for the client |
| `hmacProof` and the authed headers | `hmacProof` in `Sources/DishCore/Wire/SessionCrypto.swift`; not yet: the headers, in `DishEngine/Network` |
| Session create and update (`PUT /api/connections`), read, delete; the declarative controller set | the reconcile rules and `counterNeedsRepush` in `Sources/DishCore/Reducers/Reconcile.swift`; not yet: `DishEngine/Network` for the requests |
| Controller sub-resource (slot, per-slot `PUT` and `DELETE`) | `Sources/DishCore/Reducers/SatelliteSlots.swift` (lowest free index of four) and `lateSlotConverge` in `Reconcile.swift`; not yet: `DishEngine/Network` for the requests |
| ServerInfo and catalog (`/api/server/capabilities`, `/api/catalog`, the images) | the capability folding in `Sources/DishCore/Reducers/CapabilitySolver.swift`, `TouchpadModeResolve.swift` and `MotionIndicator.swift`; not yet: `DishEngine/Network` for the reads; the Review step's carry columns (`padCarries` in `SetupReviewMappers.swift`) are a hand-written stand-in |
| Keys: the HKDF session key, the packet AEAD (direction nonce, AAD = token) | `Sources/DishCore/Wire/SessionCrypto.swift`, pinned by the cross-repo vectors in `SessionCryptoVectorTests` |
| Packet format and the UDP messages (input, motion, battery, touchpad, heartbeat, rumble, light bar, trigger effects, player LEDs, close-notify, controller audio and haptics) | `Sources/DishCore/Wire/`: `PacketCodec.swift` (framing), `Encoders.swift` (the stream payloads, the heartbeat ack, rumble, light bar, the pointer frame), `FeedbackCommands.swift` (trigger effects, player LEDs), `AudioFrames.swift` (decoded so the receive path can skip them: iOS gives apps no pad audio), `GamepadReport.swift`, `PadSample.swift`, `ProfileLayout.swift`; `Reducers/CloseNotify.swift` for close-notify; not yet: the send path in `DishEngine/Network`, on the hot path rules in `CONTRIBUTING.md` |
| The enriched heartbeat ack and the reconcile loop | `HeartbeatAck` in `Encoders.swift`, the rules in `Reducers/Reconcile.swift`, the latency readout in `Reducers/LatencyWindow.swift`, the reconnect backoff in `Reducers/Backoff.swift`; not yet: the loop in `DishEngine/Network` |
| Liveness (the session that stops responding) | partly: the shell draws `SessionPhase.stoppedResponding` from `SessionFact`, with Reconnect; the fact has no source until the session wave |
| TOFU pinning of the control plane's certificate | the verdicts and the fingerprint in `Sources/DishCore/Reducers/Tofu.swift`; not yet: `DishEngine/Network` for the trust delegate |
| Pairing-key storage (Keychain) | not yet: `DishEngine/Network` |
| Discovery: mDNS `_satellite._udp` and the legacy beacon | partly: `Info.plist` declares `NSLocalNetworkUsageDescription` and `NSBonjourServices` (`_satellite._udp`, `_nvstream._tcp`), and `LocalNetworkAccess` is the seam (`Sources/DishEngine/LocalNetwork/LocalNetworkAccess.swift`); its one implementation, `RecordedLocalNetworkAccess`, browses nothing and its status stays `.unknown` |
| Versioning: the offer, the 409 range, the settled version | `Sources/DishCore/Reducers/ProtocolNegotiation.swift` |
| The error model (terminal 401 codes, 409, 503, transport) | `Sources/DishCore/Reducers/RestOutcome.swift` |
| The admin API (loopback `:9877`) | not applicable: the satellite's operator surface, not a client's |

## What exists that the contract will use

- `SetupDraft`, the answers of the setup walk (input, destination, the
  emulated pad, motion), is the shape of the binding the wire will declare.
  Bind records it in `BindingRequests` (`Sources/DishEngine/Setup/BindingRequests.swift`)
  and sends nothing.
- `EmulatedPad` (`dualSense`, `dualShock4`, `xboxWireless`, `switchPro`) and
  its `hasMotion` are `DishCore` types today; the satellite's catalog will
  replace the fixed list.
- `ConnectionFact`, `SessionFact` and `ControllerFact` are the facts the wire
  will publish; their sources are empty.

## Client behaviours required by the contract

Not yet implemented; the contract states them and the dish-mac notes show how a
Swift client keeps them (declarative topology, a session key distinct from the
pairing key, terminal 401 and 409, proactive re-key, close-notify, identity by
machine id, TOFU, both pairing paths). They become rows here, each with its
file and its test, in the wave that builds them.
