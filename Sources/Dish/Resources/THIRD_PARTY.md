# Third-party notices

Dish for iOS is licensed [LGPL-3.0-or-later](LICENSE). This file lists every
third-party component that is linked into `Dish.app`, embedded in it as a
resource, or used only to build, test and release it, and states what someone
redistributing the binary has to do.

The app links no third-party code. `Package.swift` declares no package
dependencies (`PackageGraphTests` pins that), so the binary links only Apple's
system frameworks. One protocol is ported to Swift as adapted logic from
MIT-licensed C (ENet, section 2c), and one is implemented from the
documentation and MIT source of a host (Wolf, section 2b); both notices are
kept below. Nothing is bundled but the app's own String Catalog, its
asset catalogs, the fleet's app mark and this notice, which Settings › About ›
Open source licenses shows.

---

## 1. Summary

| Component | Version | SPDX | How it reaches the user | Attribution obligation |
|---|---|---|---|---|
| Apple system frameworks (Foundation, Observation, Synchronization, SwiftUI, UIKit, os, GameController, CoreHaptics, StoreKit, Network, Security, CryptoKit, CommonCrypto) | the iOS the app runs on | Apple SDK license | Dynamically linked against the user's iOS. Nothing is bundled. StoreKit sells Support Dish's tips; the App Store, not Dish, handles the payment. | None for redistributors of the app |
| [ENet](https://github.com/cgutman/enet) (cgutman fork, commit `44c85e1`) | the fork Wolf pins | `MIT` | No C is compiled. The client subset of its reliable-UDP protocol is ported to Swift under `Sources/DishCore/Moonlight/Enet/`; section 2c. | Keep the copyright and permission notice below |
| [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) | 0.61.1 | `MIT` | Build and CI only, as a pinned release binary (`scripts/tools.sh`). Not in the app. | None for redistributors of the app |
| [SwiftLint](https://github.com/realm/SwiftLint) | 0.65.0 | `MIT` | Build and CI only, as a pinned release binary (`scripts/tools.sh`). Not in the app. | None for redistributors of the app |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | 2.46.0 | `MIT` | Build and CI only, as a pinned release binary (`scripts/tools.sh`); generates `Dish.xcodeproj`. Not in the app. | None for redistributors of the app |

The pinned tools are verified by SHA-256 against the digests in
`scripts/tools.sh` and `.github/workflows/ios-ci.yml`.

`App/Dish.storekit` is a StoreKit configuration for the simulator and for
Xcode's run action only; it lists the three tip products and is not in the app.

Everything under `App/Resources/` and `Sources/Dish/Resources/` is
TinkerNorth's own, covered by this repository's own license: the artwork (the
app mark is the fleet's, `dish-linux`'s `resources/brand/dish-logo.svg`), the
String Catalog, and `THIRD_PARTY.md`, a copy of this file that
`VersionConsistencyTests` keeps equal to it.

### CI and release tooling

Used by the workflows only. None of it is in the app or in a release artifact,
except that Syft's output (the SBOMs) and cosign's and the SLSA generator's
output (signatures, provenance) ship beside it.

| Component | Version | SPDX | Used for |
|---|---|---|---|
| [actions/checkout](https://github.com/actions/checkout) | v7.0.1 | `MIT` | every workflow |
| [actions/upload-artifact](https://github.com/actions/upload-artifact) | v7.0.2 | `MIT` | the simulator `.app`, the release payload, the gitleaks report |
| [actions/download-artifact](https://github.com/actions/download-artifact) | v8.0.2 | `MIT` | `release.yml` |
| [actions/setup-python](https://github.com/actions/setup-python) | v7.1.0 | `MIT` | the allowlist expiry check |
| [actions/dependency-review-action](https://github.com/actions/dependency-review-action) | v5.0.0 | `MIT` | `security.yml` |
| [github/codeql-action](https://github.com/github/codeql-action) | v4.39.1 | `MIT` | `codeql.yml`, and the Grype SARIF upload |
| [anchore/scan-action](https://github.com/anchore/scan-action) (Grype) | v7.4.2 | `MIT` | the release vulnerability scan |
| [anchore/sbom-action](https://github.com/anchore/sbom-action) (Syft) | v0.24.3 | `Apache-2.0` | the SPDX and CycloneDX SBOMs |
| [slsa-github-generator](https://github.com/slsa-framework/slsa-github-generator) | v2.1.0 | `Apache-2.0` | the SLSA L3 provenance |
| [softprops/action-gh-release](https://github.com/softprops/action-gh-release) | v3.0.3 | `MIT` | publishing the GitHub Release |
| [cosign](https://github.com/sigstore/cosign) | 2.4.1 | `Apache-2.0` | keyless signatures |
| [OSV-Scanner](https://github.com/google/osv-scanner) | 1.9.0 | `Apache-2.0` | `_security.yml` |
| [gitleaks](https://github.com/gitleaks/gitleaks) | 8.30.1 | `MIT` | `_security.yml` |

Each action is pinned to a 40-character commit SHA in the workflows (the SLSA
generator by its release tag, the one exception `WorkflowPinTests` allows);
the versions above are the tags the pins were taken from.

## 2. Reused facts, not reused code

Two sets of published facts are implemented here from their documentation,
not copied as code, and one protocol is ported as adapted logic (section 2c):

- **The wire protocol** itself, specified in the TinkerNorth satellite
  repository's `docs/contract.md` and shared by every Dish client: byte
  layouts, the HKDF and HMAC constructions, the AEAD nonce rule and the REST
  surface. The interop vectors in `Tests/DishCoreTests/SessionCryptoVectorTests.swift`
  are the same hex every sibling pins.
- **The Moonlight (GameStream) host protocol**, under `Sources/DishCore/Moonlight/`,
  learned from the documentation and the MIT-licensed host implementation of
  Wolf (games-on-whales/wolf) by way of dish-mac's port: the control-packet
  AES-GCM construction and its IV rule, the CONTROLLER_* and mouse wire
  layouts, the host event bodies, the media ping, the five-phase PIN pairing
  algorithm and the RTSP request and response shapes. Section 2b records that
  reuse of adapted logic. The byte-exact fixtures under
  `Tests/DishCoreTests/Moonlight/` are Wolf's published vectors and captures,
  the same hex dish-mac, dish-android, dish-linux and dish-windows pin. No
  GPL-licensed Moonlight code (moonlight-common-c, moonlight-qt,
  moonlight-android, Sunshine, Apollo) was consulted or copied.

## 2b. Wolf (Moonlight protocol reference)

Wolf, SPDX `MIT`. Upstream: <https://github.com/games-on-whales/wolf>.

**No Wolf source is compiled into Dish.** Wolf is an MIT-licensed Moonlight
*host*; its protocol documentation (`control-specs.adoc`, `input-data.adoc`,
`http-pairing.adoc`, `rtsp.adoc`) and source (`control.hpp`, `moonlight.cpp`)
were the reference for the fleet's own Moonlight *client*, which dish-mac
implemented and this project ports under `Sources/DishCore/Moonlight/`.
Adapted logic includes the control-packet AES-GCM IV construction (the low
byte of the sequence alone), the encrypted frame layout with its tag before
the ciphertext, the CONTROLLER_* and mouse struct layouts, the host event
bodies, the five-phase PIN pairing algorithm and the RTSP request and response
shapes. These were re-implemented against Dish's own architecture; the
byte-exact test fixtures are Wolf's published vectors and captures.

```
Copyright (c) 2021-2024 Games on Whales

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Deliberately NOT consulted, to keep this LGPL-3.0 project clear of GPL-3.0
Moonlight code: moonlight-common-c, moonlight-qt, moonlight-android, Sunshine,
Apollo. Wolf's documentation and MIT source were sufficient.

## 2c. ENet (the Moonlight control transport)

ENet, SPDX `MIT`. Upstream: <http://enet.bespin.org/>; the fork and commit
Wolf pins: <https://github.com/cgutman/enet>,
`44c85e16279553d9c052e572bcbfcd745fb74abf`.

**No ENet C source is compiled into Dish.** `Sources/DishCore/Moonlight/Enet/`
is a minimal pure-Swift port of the reliable-UDP client subset the Moonlight
control stream needs: the connect handshake, reliable send and receive on one
channel, acknowledgements, ping and disconnect. dish-mac ported it from the
fork's `protocol.c`, `peer.c` and `include/enet/protocol.h`: the wire structs
and `commandSizes` table, the round-trip estimate and retransmission timeout
of `enet_protocol_handle_acknowledge`, the give-up conditions of
`enet_protocol_check_timeouts`, the reliable receive window of
`enet_peer_queue_incoming_command`, and the ping rule of
`enet_protocol_send_outgoing_commands`; this project ports dish-mac's. Only
the needed subset is reproduced: this client never sends a fragmented,
unsequenced, throttle or bandwidth command and does not compress, but it
measures and acknowledges all of them on receive, because a peer packs several
commands into one datagram and a command whose size is unknown costs every
command behind it.

```
Copyright (c) 2002-2020 Lee Salzman

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 3. Keeping this in sync

`Package.swift`'s `dependencies` list is the source of truth for linked code.
A pull request that adds a package dependency also adds a row to the summary
above, commits `Package.resolved` (currently ignored because there is nothing
to resolve), and extends `.gitleaks.toml` and the SBOM expectations in
`release.yml` if the component needs it. `scripts/tools.sh` and
`.github/workflows/ios-ci.yml` carry the pinned tool versions above; a tool
bump updates both and this table in one commit, and `ToolPinTests` fails when
the two disagree. A bumped action updates its row.

## 4. Reporting an attribution problem

Open an issue, or for anything that may need to stay private, use the
security contact in [`SECURITY.md`](SECURITY.md).
