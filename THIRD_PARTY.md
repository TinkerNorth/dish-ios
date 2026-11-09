# Third-party notices

Dish for iOS is licensed [LGPL-3.0-or-later](LICENSE). This file lists every
third-party component that is linked into `Dish.app`, embedded in it as a
resource, or used only to build, test and release it, and states what someone
redistributing the binary has to do.

The app has no third-party code in it. `Package.swift` declares no package
dependencies (`PackageGraphTests` pins that), so the binary links only Apple's
system frameworks. Nothing is bundled but the app's own String Catalog, its
asset catalogs and the fleet's app mark.

---

## 1. Summary

| Component | Version | SPDX | How it reaches the user | Attribution obligation |
|---|---|---|---|---|
| Apple system frameworks (Foundation, Observation, SwiftUI, UIKit, os) | the iOS the app runs on | Apple SDK license | Dynamically linked against the user's iOS. Nothing is bundled. | None for redistributors of the app |
| [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) | 0.61.1 | `MIT` | Build and CI only, as a pinned release binary (`scripts/tools.sh`). Not in the app. | None for redistributors of the app |
| [SwiftLint](https://github.com/realm/SwiftLint) | 0.65.0 | `MIT` | Build and CI only, as a pinned release binary (`scripts/tools.sh`). Not in the app. | None for redistributors of the app |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | 2.46.0 | `MIT` | Build and CI only, as a pinned release binary (`scripts/tools.sh`); generates `Dish.xcodeproj`. Not in the app. | None for redistributors of the app |

The pinned tools are verified by SHA-256 against the digests in
`scripts/tools.sh` and `.github/workflows/ios-ci.yml`.

Everything under `App/Resources/` and `Sources/Dish/Resources/` is original
TinkerNorth artwork (the app mark is the fleet's, `dish-linux`'s
`resources/brand/dish-logo.svg`), covered by this repository's own license.

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

Nothing is reused in this wave. The wire protocol is specified in the
TinkerNorth satellite repository's `docs/contract.md` and shared by every Dish
client; when the wave that implements it lands, this section lists the
published facts it follows (as dish-mac's does) and the cross-repo vectors it
pins.

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
