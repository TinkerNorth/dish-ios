# Dish iOS

The native iPhone client for the Satellite wireless-gamepad server, one of the
Dish clients beside [dish-mac], [dish-android], [dish-windows] and
[dish-linux]. It is meant to find a Satellite on the Wi-Fi, pair with it,
declare the iPhone's controllers to the server and stream their input to the
PC. **This is wave 1, the shell: nothing talks to a PC yet.** See
[Status](#status) for what is built and what is not.

[dish-mac]: https://github.com/TinkerNorth/dish-mac
[dish-android]: https://github.com/TinkerNorth/dish-android
[dish-windows]: https://github.com/TinkerNorth/dish-windows
[dish-linux]: https://github.com/TinkerNorth/dish-linux

<a href="https://github.com/TinkerNorth/dish-ios/actions/workflows/ios-ci.yml"><img alt="iOS CI" src="https://github.com/TinkerNorth/dish-ios/actions/workflows/ios-ci.yml/badge.svg"></a>
<a href="https://github.com/TinkerNorth/dish-ios/actions/workflows/security.yml"><img alt="Security" src="https://github.com/TinkerNorth/dish-ios/actions/workflows/security.yml/badge.svg"></a>
<a href="https://github.com/TinkerNorth/dish-ios/actions/workflows/codeql.yml"><img alt="CodeQL" src="https://github.com/TinkerNorth/dish-ios/actions/workflows/codeql.yml/badge.svg"></a>
<a href="https://github.com/TinkerNorth/dish-ios/actions/workflows/version-consistency.yml"><img alt="Version consistency" src="https://github.com/TinkerNorth/dish-ios/actions/workflows/version-consistency.yml/badge.svg"></a>

## Status

Wave 1 builds the app's shell and everything around it, and wires none of the
sources. The engine publishes real facts that are empty: no controllers, no
connections, no session, and a Local Network status that stays unknown. Every
content state is still built, tested through its mapper and shown in a
`#Preview`, so the next waves only connect sources. Nothing opens a socket,
reads a controller or sends a byte.

What works today:

- **The shell.** A tab bar with three tabs, Controllers, Connections and
  Settings, each its own `NavigationStack`; the session accessory
  (`tabViewBottomAccessory`) with its inline form, present only while a
  session exists, which is never yet; the two covers, setup and the dim, as
  `fullScreenCover`s.
- **The setup flow.** Welcome, then Input (1 of 3), Destination (2 of 3: the
  Local Network primer, then Pick your PC) and Binding (3 of 3: Review and
  bind). It rises on the first launch and from Settings › Setup guide, and
  "Add a controller" opens it at Input. Skip on any step lands on
  Controllers. The walk is a pure machine in `DishCore`; Bind records the
  request and sends nothing.
- **The low-power dim.** A black cover that a tap wakes. Nothing raises it yet,
  because its button lives on the session accessory.
- **Settings.** Name on your PC, Keep screen on, Dim screen after, Setup
  guide, Appearance (System, Light, Dark) and the version, stored in
  `UserDefaults`.
- **The empty Controllers and Connections pages**, and the Connections page's
  "Dish can't see your network" state, which nothing reaches at run time yet.
- **Six languages**, English, Bosnian, German, Spanish, French and Brazilian
  Portuguese, in one String Catalog.

What is not built is listed, row by row with where it lands, in
[`Tests/PARITY.md`](Tests/PARITY.md): the GameController bridge, discovery,
pairing, the wire protocol, the controller and PC detail pages, the play
screens, Support Dish, Help & FAQ, Diagnostics and the rest.

## Requirements

- iOS 26.0 or newer, iPhone only, portrait only in this wave. There is no
  fallback for an older iOS anywhere.
- Xcode 26.6 or newer (Swift 6.3) to build; CI builds on `macos-26` with its default Xcode 26.6, and the tree is also verified on Xcode 27.
- To build from a clone, the checkout folder must be named `dish-ios`, as CI's
  is: XcodeGen names the project's local package reference after the folder,
  and `scripts/generate-project.sh --check` fails on any other name.

No third-party dependency: the package depends on Apple's frameworks alone.

## Build and run

```bash
open Dish.xcodeproj          # scheme DishApp, product Dish.app
```

`Dish.xcodeproj` is generated from `project.yml` by XcodeGen and committed, so
a clone opens in Xcode without tools. After editing `project.yml`:

```bash
scripts/generate-project.sh          # regenerate
scripts/generate-project.sh --check  # fail on drift, as CI does
```

The first launch on a fresh install shows the setup cover; Skip lands on the
tabs.

## Testing

One command builds the app and runs every package test target:

```bash
xcodebuild test -project Dish.xcodeproj -scheme DishApp \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

The scheme lists every test target of the package, and `PackageGraphTests`
pins that list, so a new target that is not in `project.yml` fails the build.

| Target | What it pins |
|---|---|
| `DishCoreTests` | The setup machine: every step, every event, the Local Network branches and the draft's defaults. |
| `DishKernelTests` | `StateSource`: distinct-until-changed publishing. |
| `DishEngineTests` | The preference stores, the clock, the setup intents, the Local Network seam, the binding record, the page lifecycle. |
| `DishTests` | Every mapper flow (empty, content, each variant), the navigation machine and the navigation store. |
| `ArchitectureTests` | Import boundaries, the package graph, license headers, no suppressions, lint thresholds, tool pins, workflow pins, the version mirrors, the catalog, the tokens, view purity, navigation coverage. |

## Development

The whole CI gate, locally, with SwiftFormat 0.61.1, SwiftLint 0.65.0 and
XcodeGen 2.46.0 fetched once at the pinned checksums CI uses:

```bash
scripts/ci-local.sh           # format, lint strict, project drift, tests, Release build
scripts/ci-local.sh --quick   # skip the Release build
scripts/ci-local.sh --no-tests  # build the tests but do not run them
scripts/setup-hooks.sh        # pre-commit: format + lint on staged Swift files
```

`DISH_SIM_DESTINATION` overrides the simulator destination, for example
`platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro` when several runtimes are
installed. [`CONTRIBUTING.md`](CONTRIBUTING.md) holds the rules: zero
warnings, the shape of the code, tests red first for every flow, where code
goes, and how a release is cut.

## Architecture

One SwiftPM package at the root carries four modules, so the compiler
enforces the layering:

```
DishCore      the pure core: the setup machine now, the wire codecs and
              crypto later                                   (Foundation)
DishKernel    the dataflow primitive: StateSource      (Foundation + Observation)
DishEngine    the stores, the clock, the seams and AppModel, the one
              composition root (depends on Core and Kernel;
              no SwiftUI, no UIKit)
Dish          the SwiftUI library: the scene, the shell, the pages, the theme
              and the localized words           (depends on all three)
```

A thin app target, `DishApp`, is generated by XcodeGen from `project.yml`;
`App/Sources/DishApp.swift` is the `@main` and only calls `DishScene()`. The
rules behind the layering, and why each exists, are in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); `Tests/ArchitectureTests`
fails the build when a file imports outside its module's allowlist, a
dependency points the wrong way, a view holds a raw colour or an English
literal, or a mutable static appears.

The hot path does not exist yet. When it does, a controller report leaves
`sendto()` with no lock, no allocation and no main-actor hop, on the
controller's own queue; the rules to carry are in
[`CONTRIBUTING.md`](CONTRIBUTING.md#touching-the-hot-path-later-waves).

## Project layout

```
dish-ios/
├── Package.swift                 # four modules + five test targets; warnings are errors
├── project.yml                   # the app target and the scheme; XcodeGen's input
├── Dish.xcodeproj/               # generated from project.yml, committed, drift-checked
├── App/                          # Sources/DishApp.swift (@main), Info.plist, Dish.entitlements, Resources/Assets.xcassets
├── Sources/DishCore/Setup/       # the setup machine and its models
├── Sources/DishKernel/           # StateSource
├── Sources/DishEngine/
│   ├── AppModel*.swift           # the composition root; intents by topic (Setup, Preferences, Pages)
│   ├── Models/                   # the facts the UI draws: controllers, connections, session, preferences, shell
│   ├── Preferences/              # the UserDefaults-backed stores
│   ├── Clock/                    # the minute clock and its ticker seam
│   ├── LocalNetwork/             # the Local Network seam and its recording implementation
│   └── Setup/                    # the recorded binding requests
├── Sources/Dish/
│   ├── DishScene.swift           # the one scene (public)
│   ├── L10n/                     # every word, and the one reader of the catalog
│   ├── Navigation/               # the navigation machine and its store
│   ├── Resources/                # Localizable.xcstrings, Media.xcassets (the app mark)
│   └── UI/                       # Theme.swift, Kit/, Mappers/, Pages/, Shell/, Setup/
├── Tests/DishCoreTests/          # the setup machine
├── Tests/DishKernelTests/        # StateSource
├── Tests/DishEngineTests/        # stores, clock, intents, seams
├── Tests/DishTests/              # mappers/ and navigation/
├── Tests/ArchitectureTests/      # the rules a compiler cannot read
├── Tests/PARITY.md               # what the other clients have, and where it lands
├── docs/design/                  # the design handoff (boards, screens, README)
├── docs/ARCHITECTURE.md          # the module map and the dataflow rules
├── docs/UI_CONTRACT.md           # the shell, the pages, the kit rules
├── docs/contract.md              # contract concept -> file (almost all not yet)
├── scripts/                      # ci-local, generate-project, tools, setup-hooks, render-icon
└── .github/workflows/            # ios-ci, security, codeql, version-consistency, release
```

## Design

The design handoff is [`docs/design/README.md`](docs/design/README.md): the
navigation model, the screen index, the boards and the copy rules.
[`DESIGN.md`](DESIGN.md) lists the tokens as the code declares them, and
[`docs/UI_CONTRACT.md`](docs/UI_CONTRACT.md) states the shell and the rules a
view obeys.

## Protocol

Not yet implemented. When it is, this client will offer **protocol 3**, with
control on `:9443` (HTTPS REST), data on `:9876` (encrypted UDP) and discovery
on `:9879`, as the fleet does. The client-server contract lives in one place,
[`satellite/docs/contract.md`][contract]; nothing here restates it.
[`docs/contract.md`](docs/contract.md) maps each contract concept to the Swift
file that will implement it.

[contract]: https://github.com/TinkerNorth/satellite/blob/main/docs/contract.md

## Languages

Every word the app shows is a property of `L10n`
(`Sources/Dish/L10n/`), read from the String Catalog
`Sources/Dish/Resources/Localizable.xcstrings` in six languages. A new word
is one property and one catalog entry with all five translations;
`LocalizationTests` fails the build on a key the catalog lacks, an entry no
code uses, a language missing a translation, a placeholder lost in
translation, or an English literal in a view.

## Contributing

Changes land on `main` through a pull request. `iOS CI` runs the format check,
strict lint, the project drift check, the tests and the Release build on every
PR; `version-consistency` checks that `VERSION`, the changelog heading and
`MARKETING_VERSION` agree; the `Security` and `CodeQL` workflows run alongside
(action-pin lint, allowlist expiry, OSV-Scanner, gitleaks, dependency review,
CodeQL `swift`). The PR template asks for the shape rules, the tests and the
bookkeeping.

## Security

Vulnerability disclosure: [`SECURITY.md`](SECURITY.md). Every release ships
cosign keyless signatures, SHA256SUMS, SBOMs (SPDX and CycloneDX) and SLSA L3
provenance; the verification recipe is in [`SECURITY.md`](SECURITY.md) and
[`CONTRIBUTING.md`](CONTRIBUTING.md#verifying-a-release-artifact).

## Privacy

[`PRIVACY.md`](PRIVACY.md) is the policy. In this wave the app makes no
network connection at all, has no account, no analytics and no crash
reporting, and stores only its preferences on the device. The Info.plist
declares the Local Network permission and the Bonjour services the discovery
wave will browse; nothing browses them yet.

## Code signing policy

Releases sign and upload to App Store Connect only when the repository holds
the six App Store secrets named in the header of
[`release.yml`](.github/workflows/release.yml). Without them the workflow
ships an unsigned IPA, `dish-X.Y.Z-unsigned.ipa`, also published under the
stable name `dish-ios.ipa`; it installs only after re-signing. Verify a
download against `SHA256SUMS`, its cosign signature and the SLSA provenance.
Nothing built locally, on a pull request or from a fork is ever signed with
the distribution certificate.

**Team.** Committers, reviewers and approvers: Emir Hasanbegovic
([@emir-hasanbegovic](https://github.com/emir-hasanbegovic)), owner of the
TinkerNorth organisation
([organisation owners](https://github.com/orgs/TinkerNorth/people?query=role%3Aowner)).

**Third-party components.** None at run time. The build tools (SwiftFormat,
SwiftLint, XcodeGen) and the GitHub Actions the workflows use are listed, with
versions and licences, in [`THIRD_PARTY.md`](THIRD_PARTY.md).

## License

GNU Lesser General Public License v3.0 or later. See [`LICENSE`](LICENSE)
(the LGPL) and [`COPYING.GPL3`](COPYING.GPL3) (the GPL v3 it incorporates).
