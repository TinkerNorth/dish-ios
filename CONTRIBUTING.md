# Contributing to Dish iOS

Thanks for contributing to the iPhone client. This document captures the
conventions that are not obvious from reading the code: the gates, where code
goes, the shape of the code, and what CI enforces.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By
participating, you agree to uphold it. Report unacceptable behavior to
`security@tinkernorth.com`.

## Getting set up

```bash
# 1) Install Xcode 26.6 or newer (Swift 6.3, the iOS 26 SDK and an
#    iPhone 17 Pro simulator; the tree is also verified on the newest Xcode)
# 2) Name the checkout folder dish-ios, as CI's is (see below)
# 3) Point git at the in-tree pre-commit hook
scripts/setup-hooks.sh
# 4) Run every CI gate against your worktree, in CI's order
scripts/ci-local.sh
```

`scripts/ci-local.sh` downloads the same SwiftFormat 0.61.1, SwiftLint 0.65.0
and XcodeGen 2.46.0 release binaries CI pins (`scripts/tools.sh`, verified by
SHA-256, into `.build/tools`), then runs the format check, the strict lint,
the project drift check, `xcodebuild test` on a simulator and the Release
build. A green run there is a green `ios-ci.yml` run. `--quick` skips the
Release build, `--no-tests` builds the tests without running them, and
`DISH_SIM_DESTINATION` overrides the destination (the default is
`platform=iOS Simulator,name=iPhone 17 Pro`; pin an OS with
`platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro` when several runtimes are
installed). Homebrew's SwiftFormat and SwiftLint track their latest and will
flag rules the pins do not know; use the script's copies. A pin bump is a
deliberate commit that reformats or regenerates the tree with it, in
`scripts/tools.sh`, `ios-ci.yml` and `THIRD_PARTY.md` together;
`ToolPinTests` fails when the script and the workflow disagree.

One command runs every test:

```bash
xcodebuild test -project Dish.xcodeproj -scheme DishApp \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

Add `-only-testing:ArchitectureTests/ThemeTokenTests` (or any class) to run
less while you work red-first.

The pre-commit hook runs `swiftformat` (autofix, re-stages) and
`swiftlint --strict` on staged Swift files and skips when the tools are not
on your `PATH` or in `.build/tools`; CI re-runs both, so anything that slips
locally fails the PR.

### The project is generated

`Dish.xcodeproj` is generated from `project.yml` by XcodeGen and committed, so
a clone opens in Xcode without tools. Edit `project.yml`, run
`scripts/generate-project.sh` and commit both. CI runs
`scripts/generate-project.sh --check` and fails on any drift. XcodeGen names
the project's local package reference after the checkout's folder, so the
checkout must be called `dish-ios`, as CI's is; under another name the check
fails and says so. When you add a test target to `Package.swift`, add it to the
`DishApp` scheme's test list in `project.yml` too: `PackageGraphTests` pins
that the scheme lists every package test target, and the UI test bundle
beside them.

## Where code goes

The app is one SwiftPM package of four modules whose dependency arrows point
one way, plus a thin app target. The layering is enforced in code: SwiftPM
holds the graph, and `Tests/ArchitectureTests` pins which frameworks each
module may import.

| You have... | It goes in | May import |
|---|---|---|
| a `(state, event) -> result` decision with no IO, and later a wire codec or a crypto primitive | `DishCore` (`Sources/DishCore`) | Foundation |
| a dataflow primitive | `DishKernel` (`Sources/DishKernel`) | Foundation, Observation |
| a store, a seam to the platform, a clock, an intent, or the composition root | `DishEngine` (`Sources/DishEngine`) | Foundation, Observation, os, DishCore, DishKernel; never SwiftUI or UIKit |
| a view, a theme token, a localized word, a mapper, or the navigation | `Dish` (`Sources/Dish`) | SwiftUI, Observation, Foundation, the three modules; UIKit only in `UI/Theme.swift` and `DishScene.swift`; never Network, GameController, Security, CryptoKit |
| the `@main` | `App/Sources/DishApp.swift` | SwiftUI, Dish |

Within the engine, pick the primitive that matches what the thing does:

| You have... | Use |
|---|---|
| state owned from a socket, timer, cache or setting | a store that **holds** a `StateSource<S>` |
| a UI-facing mutation | an intent, a method of `AppModel` in an extension by topic (`AppModel+Setup.swift`) |
| a platform capability the tests must replace (a ticker, the Local Network permission) | a protocol seam, with the production implementation beside it |
| imperative commands spanning several sources | a coordinator, constructed by `AppModel` |

`StateSource` is held, not subclassed: it is a `final class`, and a store has
one as a private property and forwards its `state`. The kernel's other
primitives (`Composer`, `Controller`, `Repository`, `AsyncState`) are not
ported yet; the rows for them are in [`Tests/PARITY.md`](Tests/PARITY.md).

The rules, and why each exists, are in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Two that catch people out: the engine never words anything (a fact is an enum
or a number; the app's mapper turns it into a sentence), and a view never
reaches an engine object (it calls an intent on `AppModel` or sends an event
to `NavigationStore`). The engine's UI-facing surface is `package`; the app is
`public` only at `DishScene`; everything else is `internal`, and tests reach
it through `@testable import`.

## Touching the mark

`Resources/Dish.svg` is the fleet's app mark (`dish-linux/resources/brand/dish-logo.svg`,
byte for byte). `scripts/render-icon.sh` (`brew install librsvg` for
`rsvg-convert`) renders two build products from it that are kept in the tree:
the 1024 px app icon, `App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`,
and the in-app mark as 1x, 2x and 3x PNGs under
`Sources/Dish/Resources/Media.xcassets/DishMark.imageset/`. The mark ships as
pixels because neither Xcode's SVG import nor CoreGraphics' PDF drawing keeps
the mask that cuts the gear ring. Change the mark across the fleet, copy it
here, run the script and commit the renders with it.

## Touching the UI

Every design value reaches its call site through a name in
`Sources/Dish/UI/Theme.swift`: a `DishTheme` colour, a `DishFont` Dynamic Type
style, a `DishSize` or `DishSpace` measure, a `DishSymbol` or a `DishImage`.
[`DESIGN.md`](DESIGN.md) is the token reference and lists every one. A view
outside `Theme.swift` writes no raw colour, no raw font size, derives no
colour from a token (an alpha-tinted colour is a token of its own), and a kit
component sets no raw size; `ThemeTokenTests` fails the build on one, and on a
token `DESIGN.md` does not list or no code draws.

Do not restyle what iOS 26 draws: the tab bar, the toolbars and the glass are
the system's, and a list's corners come from `List` (`.insetGrouped`),
`Section`, `Toggle`, `Picker` and `Menu`, not from a number in a view.

Every user-facing word reaches a view through `L10n`
(`Sources/Dish/L10n/L10n+<Screen>.swift`); its `StringCatalog` is the one
reader of the compiled catalog, and a view never holds an English literal.
Derivation (a row's text, a dot's colour, an enabled flag, a fallback word) is
a pure function under `Sources/Dish/UI/Mappers/<Page>Mappers.swift` returning
an `Equatable` view-state struct whose last parameter is `words: L10n = .app`,
tested in `Tests/DishTests/Mappers/<Page>MappersTests.swift`, one test per flow
(empty, content, each variant). Never an expression inside a `body`:
`ViewPurityTests` rules V1 to V12 read every view for a clock, IO, formatting,
an engine object, a decision on a fact, a picked token, a boolean rule or a
fallback word. Navigation is data: a view sends
`navigation.send(.push(.deviceName))` and holds no `NavigationPath` or
`isPresented` of its own for app navigation. The shell, the page rules and the
kit rules are in [`docs/UI_CONTRACT.md`](docs/UI_CONTRACT.md); the design
handoff is [`docs/design/README.md`](docs/design/README.md).

A new tab, page or cover is whole or it does not build:
`NavigationCoverageTests` requires its worded title, its `<Name>Page.swift`
(or `<Name>Cover.swift`), its `<Name>MappersTests.swift` and a branch of the
shell's switch.

## Translations

Six languages (en, bs, de, es, fr, pt-BR) live in one String Catalog,
`Sources/Dish/Resources/Localizable.xcstrings`. Xcode's build system compiles
it into per-language tables inside the `Dish` resource bundle. A key is the
English text written as a C format string, one sentence per key, on one line,
using only `%@`, `%lld` and `%%`; a count that needs a plural form is a
`%lld` key with plural variations (today `%lld pads` and `%lld controllers`;
Bosnian also has a paucal form). The two duration keys `%lld s` and `%lld min`
carry no plural forms yet, which `Tests/PARITY.md` lists.

A new user-facing string needs its `L10n` property, its catalog entry and all
five translations in the same commit: `LocalizationTests` fails on a key
`L10n` uses that the catalog lacks, on a catalog entry no code uses, on any
language missing a translation, on a translation not marked translated, on a
placeholder lost in translation, and on an English literal in a view, because
a missing translation is not a blank, it is English shown to someone who does
not read English. Copy rules from the design: no emoji, no exclamation marks,
no em dashes, and the fleet's terms spelled as the design spells them
(Controllers, Connections, Settings, Bind, Unbind, Emulate as, Satellite,
Moonlight host, Reconnect, Forget This PC).

## License headers

Every source file (`*.swift`) starts with:

```swift
// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
```

`Package.swift` carries them on lines two and three, after the tools-version
comment. `LicenseHeaderTests` fails on a file without them. Don't introduce
code under a different license: the project is LGPL-3.0-or-later end-to-end
(`LICENSE`, `COPYING.GPL3`, source headers).

## Style

`.swiftformat` and `.swiftlint.yml` are authoritative for layout; run
`.build/tools/swiftformat .` to fix and `.build/tools/swiftlint lint --strict`
to check (after `scripts/ci-local.sh` has fetched them). This section is about
what a formatter cannot check.

The platform floor is fixed: iOS 26.0, Swift 6 language mode with strict
concurrency (`swiftLanguageModes: [.v6]` in the package,
`SWIFT_STRICT_CONCURRENCY: complete` in the project), and no fallbacks for an
older iOS: no `if #available`, no custom session bar. State is Observation
(`@Observable`); `ObservableObject`, `@Published` and Combine are not used.

### Zero warnings

Every Swift compiler warning fails the build: each target in `Package.swift`
carries `.treatAllWarnings(as: .error)`, and the app target sets
`SWIFT_TREAT_WARNINGS_AS_ERRORS`. SwiftLint runs `--strict` for the same
reason. A warning is fixed at its cause, never suppressed: no
`// swiftlint:disable`, no `-suppress-warnings`, no `unsafeFlags`, no
`TODO`/`FIXME`/`HACK` comment, no `@unchecked Sendable` and no
`nonisolated(unsafe)`. `NoSuppressionsTests` and `PackageGraphTests` scan for
each. There is no exception today.

The caps (a warning fails CI): line 140, function body 45, type body 300,
file 500, cyclomatic complexity 10 (exhaustive `switch` arms do not count),
parameters 8. `LintConfigTests` pins the thresholds this document names.

CI builds on the `macos-26` runner image with its default Xcode (26.6, Swift
6.3.3). The tree must be warning-free there and on the newest Xcode (27.x,
Swift 6.4 locally); write code that both compile, and use nothing that
arrived after the iOS 26 SDK. The older compiler is also the stricter judge:
it refused to lower a main-actor function reference handed straight to
`Binding(get:set:)`, so a setter there is a one-expression closure
(`set: { select($0) }`), never a bare method reference.

### Shape of the code

These rules come from the Parchment library and are adapted where Swift and
SwiftUI make the literal form worse than the thing it is meant to achieve.
They apply to `Sources/` and `Tests/` alike, and they are the rules the other
Dish clients follow, so a fact ported between clients keeps its shape.

- **As immutable and as static as possible.** `let` over `var`; a value known
  at compile time is a `static let` or a file-level `let`, never a literal in
  the middle of a function; `private` unless something outside needs it,
  `package` for what another module of the package binds, and `public` only
  for `DishScene`. A type that holds no state is a set of free functions or an
  `enum` of static functions, not a class. A `struct` unless identity demands
  a reference.

- **Split values into simple, named steps.** One operation per line, with the
  result in a named `let` that says what it is, even when that reads longer:

  ```swift
  let sessionUp = facts.session != nil
  return sessionUp && facts.preferences.keepScreenOn
  ```

  not one five-term boolean. The names are the documentation, the debugger
  can show each value, and a test can pin each step.

- **One function, one flow.** When a function would hold two algorithms chosen
  by a condition, the condition dispatches to two named things that each do
  one thing, and the dispatcher does nothing else. An exhaustive `switch`
  over an enum with no `default` is the preferred form, because the compiler
  then checks that every case is handled: `reduceNavigation` is one arm per
  event. A guard clause is not an algorithm: do not invent indirection where
  there is only one flow.

- **A callback with a body gets a name.** A closure is fine as a
  one-expression forward, as the argument of a standard-library algorithm
  (`map`, `filter`, `first`), and as a SwiftUI view builder. A closure that
  carries an algorithm becomes a method, so it can be found, read and tested
  on its own, and a callback that is stored rather than called immediately
  prefers a method reference (`endSetup: model.endSetup`).

- **No singletons.** A stateless helper is a free function in the file that
  owns it. There is no `static var` and no `.shared` of our own; every
  collaborator is constructed by `AppModel` or `DishScene`, the composition
  roots, and handed to whoever needs it, which is also what makes it
  replaceable in a test. `UIApplication.shared`, `UserDefaults.standard`,
  `UIDevice.current` and `Bundle.main` are read only in
  `Sources/Dish/DishScene.swift`, never under `UI/` and never in the engine;
  `NoSuppressionsTests` pins both rules. A `static let` of an immutable value
  (a key, a table, a constant) is a constant, not a singleton.

- **No discarded results.** A value is either used or not produced. `_ =` is
  for a result the code deliberately ignores, and the line beside it says why.

- **The engine vends data, the app vends words.** A fact is an enum or a
  number (`LinkHealth.unsteady`, `ConnectionState.offline(lastSeen:)`); the
  mapper words it. No `String` built for display in `DishEngine`.

- **Prefer a test to a comment.** Behaviour that needs explaining gets a test
  named for the behaviour. A doc comment says what a type is for in one or
  two lines; a comment is the last resort for a constraint that genuinely
  cannot be tested (a platform quirk, a framework's threading contract),
  states why, and never narrates what the next line does. Exempt, because the
  constraint is untestable by construction: the pin-map headers in
  `.github/workflows/`, the usage headers in `scripts/`, and `Package.swift`
  and `project.yml`, where a comment explains what a setting is holding back.
  Deferred work goes in [`Tests/PARITY.md`](Tests/PARITY.md) or an issue,
  never a `TODO`.

## Tests

| Target | Covers | Reaches |
|---|---|---|
| `Tests/DishCoreTests` | the setup machine: every step, event and Local Network branch | `DishCore` |
| `Tests/DishKernelTests` | `StateSource` | `DishKernel` |
| `Tests/DishEngineTests` | the preference stores, the clock against a `ManualTicker`, the setup intents, the Local Network seam, the binding record, the page lifecycle; `TestDefaults` makes a fresh `UserDefaults` per test | `@testable import DishEngine` |
| `Tests/DishTests` | the app layer where it decides: every mapper under `Mappers/`, the navigation machine and the navigation store under `Navigation/` | `@testable import Dish` |
| `Tests/ArchitectureTests` | the rules of the repository, read from the tree | the file system |
| `App/UITests` (`DishUITests`, a target of the project, not the package) | the shell's critical path through the real app on the simulator: a first run under the welcome, Skip landing on Controllers, Add a controller opening the first step, Settings reopening the guide; the onboarding flag is set through launch arguments | the running app, by its labels |

`Tests/ArchitectureTests` is where knowledge written twice is checked:

| Test class | Rule |
|---|---|
| `ImportBoundariesTests` | each layer imports only its allowlist; the engine never imports SwiftUI or UIKit; the UI layer does no IO; only the scene and the theme import UIKit; a kit component imports only SwiftUI and Foundation and reads no model |
| `PackageGraphTests` | core and kernel depend on nothing, the engine on both, the UI library on all three; no third-party package; every target treats warnings as errors; Swift 6 mode, iOS 26, tools-version 6.2; the scheme lists every test target |
| `LicenseHeaderTests` | the two-line SPDX header on every Swift file and on the manifest |
| `NoSuppressionsTests` | no lint suppression, no deferred-work comment, no mutable static, no host singleton outside the scene, no unchecked concurrency |
| `LintConfigTests` | the lint thresholds this document names; CI runs SwiftLint strict and SwiftFormat in lint mode |
| `ToolPinTests` | `scripts/tools.sh` and `ios-ci.yml` pin the same tool versions and digests |
| `WorkflowPinTests` | every `uses:` is a 40-character commit SHA (the SLSA generator's release tag is the one exception) |
| `VersionConsistencyTests` | `VERSION` is `MAJOR.MINOR.PATCH`, `project.yml` carries it as `MARKETING_VERSION`, the changelog's newest heading names it or is `[Unreleased]`, the Info.plist reads both bundle versions from build settings |
| `LocalizationTests` | the catalog and the funnel agree, in every language, with placeholders intact; no view holds an English literal |
| `ThemeTokenTests` | no raw colour, font size or kit size; `DESIGN.md` lists every token; every token outside the shared palette is drawn |
| `ViewPurityTests` | rules V1 to V12 of [`docs/UI_CONTRACT.md`](docs/UI_CONTRACT.md) |
| `NavigationCoverageTests` | every tab, page and cover is worded, built, tested and drawn |

### Test-driven, every flow

- **Red first.** Write the failing test, watch it fail for the reason you
  expect, then write the code. A test that has never failed has not been
  shown to test anything; when adding a test for behaviour that already
  exists, break the behaviour on purpose and watch the test catch it. Say in
  the PR which tests failed before the change.

- **Cover every flow, not every line.** Each branch a function can take, each
  early return, and each state a machine can be in when the new code runs
  gets its own case, named for the behaviour it pins
  (`testSkippingSetupLandsOnControllersAndCompletesTheWelcome`), not for the
  function it calls. If a branch has no test, either it is dead and goes, or
  it needs one. Every mapper state is reachable from a test.

- **Assume nothing; validate with a probe.** Where behaviour depends on a
  framework (what the tab bar's accessory placement reports, when
  Observation delivers), prove it with a test or a throwaway probe before
  writing the code that assumes it. Keep the test if it pins a dependency;
  delete it if it was only a probe.

- **Test where the behaviour lives.** A decision in its reducer's test, a
  word in its mapper's test, a flow in the engine's intent tests, and only
  what genuinely needs the screen in a `#Preview`. A test that reaches two
  layers down is testing the wrong thing.

- **Knowledge written twice is checked by a test.** When the same fact lives
  in two places (a lint threshold and this file, a token and `DESIGN.md`, a
  catalog key and a translation), a test walks one and requires the other.

- **Tests follow the same shape rules.** A fixture is a named type, not a
  closure that builds one; a helper with a body gets a name. A test touching a
  `@MainActor` type is a `@MainActor final class ...Tests: XCTestCase`. A
  fresh `UserDefaults` comes from `TestDefaults.fresh(self)`
  (`Tests/DishEngineTests/TestDefaults.swift`); copy the two-line helper into
  another test target rather than reaching across.

## Branching & PRs

- All changes land on `main` via pull request: no direct pushes.
- Commits and PR descriptions name no tool. No `Co-Authored-By` trailer for an
  assistant, no "Generated with ..." footer: the author of record is the person
  who opened the PR, whatever helped write it.
- Use the PR template (`.github/pull_request_template.md`) to describe the
  change, the tests that failed before it, the manual check you ran (what you
  tapped, on an iPhone or the simulator), and call out anything that touches
  the wire protocol. Anything user-facing adds a line under
  `## [Unreleased]` in `CHANGELOG.md`, and a row change in
  `Tests/PARITY.md` lands in the same change.
- Keep commits focused; squash noisy fixup commits before review.

> **Note on branch protection.** Treat the PR-based flow as a convention
> unless the platform enforces it, and rely on CI as the quality gate.

## What CI runs

Build + style:

- `ios-ci.yml`, on `macos-26`: the pinned tools, `swiftformat --lint`,
  `swiftlint --strict`, `scripts/generate-project.sh --check`,
  `xcodebuild test` of the `DishApp` scheme on an iPhone 17 Pro simulator
  (every package test target and the UI tests), a Release build for the
  simulator, and the `Dish.app` as an artifact. There is no build cache: a restored DerivedData
  carries the previous commit's objects and compiled resource bundles, which
  is how a stale catalog shadows the current one.
- `version-consistency.yml`: `VERSION` is the source; `CHANGELOG.md`'s top
  heading and `project.yml`'s `MARKETING_VERSION` must agree with it.

Security gates (also blocking):

- `security.yml`, which calls `_security.yml`: action-pin lint, vulnerability
  allowlist expiry, OSV-Scanner, gitleaks secret scan, GitHub
  `dependency-review-action`.
- `codeql.yml`: CodeQL `swift` analysis (security-extended +
  security-and-quality query packs) over the simulator build.

If any step fails, the PR is blocked. `scripts/ci-local.sh` runs the build and
style gates locally in the same order. There is no end-to-end lane and no
bench yet; both are in `Tests/PARITY.md`.

## Security

### Adding a vulnerability allowlist entry

Open a PR that adds an entry to [`.security/allowlist.yaml`](.security/allowlist.yaml)
(see the schema in the file). Required fields: `cve`, `reason`, `owner`,
`expires`. CI rejects the PR if any field is missing or `expires` is in the
past. Renew or remove on or before `expires`.

### Running security checks locally

```bash
# Action-pin lint (40-char SHA enforcement on every uses: line)
grep -REn '^\s*uses:' .github/workflows/ \
  | grep -vE '@[0-9a-f]{40}\b' \
  || echo "all pinned"

# Allowlist expiry
python3 - <<'PY'
import datetime, yaml, sys
data = yaml.safe_load(open('.security/allowlist.yaml').read()) or {}
for e in data.get('exceptions', []) or []:
    if datetime.date.fromisoformat(str(e['expires'])) < datetime.date.today():
        print('EXPIRED:', e); sys.exit(1)
PY

# OSV-Scanner against the worktree
osv-scanner --recursive --skip-git .

# Gitleaks
gitleaks detect --no-banner --redact --source .
```

The pin lint's grep also lists the SLSA generator, which is pinned by its
release tag because the generator only works that way; `WorkflowPinTests`
names the same exception.

### Verifying a release artifact

Each GitHub Release ships `dish-X.Y.Z-unsigned.ipa` (until the App Store
secrets exist; with them the signed archive goes to App Store Connect and
TestFlight instead) and its stable-name copy `dish-ios.ipa`, `*.sig`/`*.crt`
(cosign keyless), `SHA256SUMS` + `SHA256SUMS.sig`/`*.crt`, the SPDX +
CycloneDX SBOMs, and `dish-ios.intoto.jsonl` (SLSA L3).

```bash
shasum -a 256 -c SHA256SUMS

cosign verify-blob \
  --certificate SHA256SUMS.crt \
  --signature   SHA256SUMS.sig \
  --certificate-identity-regexp '^https://github\.com/TinkerNorth/dish-ios/\.github/workflows/release\.yml@refs/tags/[0-9].*$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  SHA256SUMS

slsa-verifier verify-artifact \
  --provenance-path dish-ios.intoto.jsonl \
  --source-uri      github.com/TinkerNorth/dish-ios \
  --source-tag      X.Y.Z \
  dish-X.Y.Z-unsigned.ipa
```

The full verification recipe lives in [`SECURITY.md`](SECURITY.md).

## Cutting a release

`release.yml` runs on a bare `MAJOR.MINOR.PATCH` tag (no `v` prefix, e.g.
`0.1.0`) or a `workflow_dispatch` with a tag input. It re-runs the security
gates against the tagged commit, asserts the tag equals `VERSION`, archives
`Dish.app`, signs it and uploads it to App Store Connect when the six App
Store secrets are present (`APP_STORE_CONNECT_KEY_ID`,
`APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`,
`IOS_DISTRIBUTION_CERT_BASE64`, `IOS_DISTRIBUTION_CERT_PASSWORD`,
`IOS_PROVISIONING_PROFILE_BASE64`), scans and signs every artifact, emits the
SBOMs and the SLSA provenance, and publishes the GitHub Release. The signing
gate is advisory, as the satellite's and the other clients' are: without the
secrets a stable tag still ships, as an unsigned IPA, with a warning in the
run and a note at the top of the release; the versioned IPA then carries
`-unsigned` while `dish-ios.ipa` keeps its name. Set the repository variable
`ENFORCE_RELEASE_SIGNING=true` to make missing secrets fail a stable tag.
There is no `latest.json`: iOS has no in-app updater, because the App Store
and TestFlight deliver updates.

Before you tag:

- **Bump `VERSION`** in a pull request of its own ("Bump the version to X.Y.Z
  and date the changelog"), turning `## [Unreleased]` into
  `## [X.Y.Z] - YYYY-MM-DD` and updating the compare link, and move
  `MARKETING_VERSION` in `project.yml` with it, then regenerate the project.
  `version-consistency.yml` fails a PR that moves one without the others.
  Raise `CURRENT_PROJECT_VERSION` when App Store Connect needs a new build
  number for the same version.
- **Update `PRIVACY.md` first** if anything about data collection changed, and
  `App/Info.plist` and `App/Dish.entitlements` with it: a new permission needs
  its usage string there, or iOS denies it.

After the workflow finishes, download `dish-ios.ipa`, check it against
`SHA256SUMS`, and install the build from TestFlight (or, for an unsigned
build, re-sign it with your own certificate and provisioning profile first).
The asset names `dish-X.Y.Z-unsigned.ipa`, `dish-ios.ipa` and `SHA256SUMS`
are a permanent API.

## Touching the hot path (later waves)

Nothing in this wave is on the hot path: there is no controller bridge and no
socket. These are the rules the waves that add them carry, taken from
dish-mac, where they are enforced by tests this repository does not have yet.
The controller's `valueChangedHandler` runs at the controller's polling rate
and must never block.

- No lock, no allocation and no main-actor hop on the send path: a report
  leaves `sendto` on the controller's own `handlerQueue`, and the kernel is
  never on that path.
- No `Task`, no `await`, no Observation on the per-event chain; direct calls
  only.
- What the hot path shares with the main actor travels in atomic words and
  mailboxes, not a lock.
- Preserve `IP_TOS = 0xB8` (DSCP EF) and `SO_NOSIGPIPE` on every send.
- Where a shape rule and the hot path disagree, the hot path wins and the
  reason goes in a test name, not a comment.
- A mailbox or a direct send before a queue. The siblings' lock-free bounded
  queue (Vyukov's: the satellite's log queue, the desktops' `MpscQueue`,
  Android's `mpmc_ring`) is not ported; `Tests/PARITY.md` says when it would
  be and in which form.
- Some of what the siblings do needs Apple's permission on iOS: the
  multicast entitlement for the legacy beacon, raw HID access for the Direct
  path. `Tests/PARITY.md` lists them; a wave that needs one asks for it first
  and ships the sanctioned path alone until it is granted.

The engine is shaped for it already: its stores publish through
`StateSource`, which is for state the UI reads, not for per-report data.

## Touching the wire protocol

Not yet. The wire protocol is a later wave and `DishCore` holds no codec today.
The macOS, Android, Windows and Linux clients all talk to the same `satellite`
server and must produce byte-identical traffic. The contract is specified in
ONE place, `satellite/docs/contract.md`; this repo's
[`docs/contract.md`](docs/contract.md) will map each concept to the Swift file
implementing it. Never restate contract facts in code comments; link them.

Ground rules for the wave that adds it:

- All protocol logic that can be pure lives in `DishCore`, pinned by the
  cross-repo interop vectors, the same hex as the satellite and the sibling
  clients. If a vector test fails, you broke the protocol, not the test.
- Sockets and REST live in `DishEngine/Network`, behind the same seams the
  stores use, so the tests replace them.
- Any change here is `[wire-coordinated]` in `CHANGELOG.md` and lands with
  `dish-android`, `dish-mac`, `dish-linux`, `dish-windows` and `satellite` in
  the same release cycle, vectors updated in lockstep on every end.

## Reporting bugs

Use the issue templates under `.github/ISSUE_TEMPLATE/`. Include the iOS
version, iPhone model, controller make/model, and the relevant console
excerpt around the misbehavior.
