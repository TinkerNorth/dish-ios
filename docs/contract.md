# Dish ↔ Satellite contract: client notes (iOS)

The protocol contract (REST surface, UDP streams, crypto, liveness,
identity) lives in ONE place: **`satellite/docs/contract.md`** in the
[TinkerNorth/satellite](https://github.com/TinkerNorth/satellite) repo. This
client is meant to offer protocol 3, as the fleet does, with control on
`:9443` (HTTPS REST), data on `:9876` (encrypted UDP) and the legacy beacon on
`:9879`; this file will record only the iOS-side mapping. When code and
contract disagree, the contract wins.

## Where the contract lands in this app

**Today it lands nowhere.** Wave 1 is the shell: `DishCore` holds the setup
machine and no codec, `DishEngine` opens no socket, and the app makes no
network connection (`PRIVACY.md`). Every row below is therefore "not yet",
with the home it is planned to have, so the wave that builds it fills the
second column instead of inventing a layout. The pure protocol layer will be
the `DishCore` target (Foundation and CryptoKit only; `ImportBoundariesTests`
lists the allowlist, and CryptoKit joins it in the wave that needs it). The
imperative shell will be `Sources/DishEngine/Network`, which owns sockets, the
URL session and the stores, behind seams the tests replace, as
`LocalNetworkAccess` is replaced today. Each row's gap is in
[`Tests/PARITY.md`](../Tests/PARITY.md).

| Contract concept | dish-ios home |
|---|---|
| Ports (9879 beacon, 9443 control, 9876 data) | not yet: `DishCore` constants, with the protocol version (3) and the opcodes |
| Identity (`deviceId`, the satellite's machine id) | not yet: `DishEngine/Network`, beside the connection store; the device's name is the one piece that exists, in `DevicePreferenceStore` (`device_name`) |
| Pairing, paths A and B (`POST /api/pair`, `GET /api/pair/status`), key rotation, delete | not yet: `DishEngine/Network` for the client; the approval verdicts and the poll's next step in `DishCore` |
| `hmacProof` and the authed headers | not yet: `DishCore` |
| Session create and update (`PUT /api/connections`), read, delete; the declarative controller set | not yet: `DishEngine/Network` for the requests, `DishCore` for the reconcile rules |
| Controller sub-resource (slot, per-slot `PUT` and `DELETE`) | not yet: `DishCore` for the slot table, `DishEngine/Network` for the requests |
| ServerInfo and catalog (`/api/server/capabilities`, `/api/catalog`, the images) | not yet: `DishEngine/Network` for the reads, `DishCore` for the capability folding; the Review step's carry columns (`padCarries` in `SetupReviewMappers.swift`) are a hand-written stand-in |
| Keys: the HKDF session key, the packet AEAD (direction nonce, AAD = token) | not yet: `DishCore`, pinned by the cross-repo vectors |
| Packet format and the UDP messages (input, motion, battery, touchpad, heartbeat, rumble, light bar, trigger effects, player LEDs, close-notify, controller audio and haptics) | not yet: `DishCore` codecs; the send path in `DishEngine/Network`, on the hot path rules in `CONTRIBUTING.md` |
| The enriched heartbeat ack and the reconcile loop | not yet: `DishCore` reducers, driven from `DishEngine/Network` |
| Liveness (the session that stops responding) | partly: the shell draws `SessionPhase.stoppedResponding` from `SessionFact`, with Reconnect; the fact has no source until the session wave |
| TOFU pinning of the control plane's certificate | not yet: `DishCore` verdicts, `DishEngine/Network` for the trust delegate |
| Pairing-key storage (Keychain) | not yet: `DishEngine/Network` |
| Discovery: mDNS `_satellite._udp` and the legacy beacon | partly: `Info.plist` declares `NSLocalNetworkUsageDescription` and `NSBonjourServices` (`_satellite._udp`, `_nvstream._tcp`), and `LocalNetworkAccess` is the seam (`Sources/DishEngine/LocalNetwork/LocalNetworkAccess.swift`); its one implementation, `RecordedLocalNetworkAccess`, browses nothing and its status stays `.unknown` |
| Versioning: the offer, the 409 range, the settled version | not yet: `DishCore` |
| The error model (terminal 401 codes, 409, 503, transport) | not yet: `DishCore` reducers |
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
