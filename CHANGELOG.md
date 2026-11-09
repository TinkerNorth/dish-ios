# Changelog

All notable changes to the Dish iOS client are documented in this file. The
format is loosely based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The version number has one source, the [`VERSION`](VERSION) file, which
`project.yml` carries as `MARKETING_VERSION` and the app's `Info.plist` reads
from the build setting. `version-consistency.yml` fails a pull request whose
`VERSION`, `CHANGELOG.md` heading and `MARKETING_VERSION` disagree, and
`release.yml` fails the tag build when the tag and `VERSION` disagree.

Cross-repo coordination: changes to the wire protocol or the pairing flow that
need matching updates in `satellite`, `dish-android`, `dish-windows`,
`dish-linux` or `dish-mac` are marked `[wire-coordinated]`. Releases tagged in
lockstep across the repos share a version number.

---

## [Unreleased]

Wave 1, the shell: the app runs and every screen of the shell is built, but
nothing talks to a PC yet. The engine publishes real, empty facts (no
controllers, no connections, no session, a Local Network status that stays
unknown); `Tests/PARITY.md` lists everything not built.

### Added

- **The shell.** Three tabs, Controllers, Connections and Settings, each its
  own `NavigationStack`, with the session accessory
  (`tabViewBottomAccessory`, and its inline form while the tab bar is
  minimized) that shows the live link on every tab while a session exists, and
  two full-screen covers, setup and the low-power dim. Navigation is data: a
  pure machine in `Sources/Dish/Navigation/NavigationMachine.swift` applies
  events and returns effects, and `NavigationStore` hands the tab bar, the
  stacks and the covers their bindings. Minimum iOS is 26.0, iPhone only,
  portrait only.
- **The setup flow.** Welcome, then Input (1 of 3), Destination (2 of 3: the
  Local Network primer while iOS has not been asked, then Pick your PC) and
  Binding (3 of 3: Review and bind). It rises once on the first launch, from
  Settings › Setup guide, and at Input from "Add a controller". Skip on any
  step lands on Controllers and completes the welcome. The walk is a pure
  machine in `DishCore` (`reduceSetup`); Bind records the request and sends
  nothing.
- **The low-power dim.** A black cover with the status bar hidden; a tap wakes
  it.
- **The Settings page.** Name on your PC (a pushed page), Keep screen on, Dim
  screen after (10, 20, 30 seconds, 1 or 2 minutes, never), Setup guide,
  Appearance (System, Light, Dark) and the version. Keep screen on holds the
  idle timer off while a session is up.
- **The Controllers and Connections pages.** The empty Controllers page with
  its "Add a controller" button, and the Connections page with its empty,
  list (paired, found on the Wi-Fi, Moonlight hosts) and "Dish can't see your
  network" states, every state built, tested through its mapper and shown in a
  `#Preview`.
- **The engine's facts and preference stores.** Facts for controllers,
  connections, the session and the shell, built from the stores; stores over
  `UserDefaults` for the appearance (the fleet's key `theme_mode`, dish-mac's
  values), the welcome (`onboarding_welcome_completed`) and, new on iOS,
  `device_name`, `keep_screen_on` and `dim_after_seconds`; a minute clock for
  words like "seen yesterday"; seams for the Local Network permission and the
  binding request, each recording what it was asked until its wave lands.
- **Support Dish.** Three optional tips (small, medium, large) sold as
  consumable in-app purchases through StoreKit 2 under
  `com.tinkernorth.dish.ios.tip.small`, `.medium` and `.large`, with the App
  Store's own localized prices, a thank-you, the pending and failed outcomes
  and Restore purchases (which finishes any tip the App Store still holds).
  It opens from the heart on the Controllers toolbar and from Settings ›
  About › Support Dish. `App/Dish.storekit` sells the three tips on the
  simulator through the scheme's run action. Apple requires in-app purchase
  for tips, so the fleet's GitHub Sponsors, Ko-fi and Buy Me a Coffee links
  are not in the app.
- **Help & FAQ.** The desktops' CONCEPTS, BEST PERFORMANCE, TROUBLESHOOTING,
  ABOUT DISH and LINKS, reworded for an iPhone (pads pair in Settings ›
  Bluetooth, iOS asks for the Local Network once, iOS suspends a Dish you
  leave, which is why it dims), with questions of its own on connecting a
  controller, the Local Network, a missing pad, the screen staying on and
  what tips pay for. Settings › Setup & help › Help & FAQ opens it.
- **Open source licenses and the About links.** Settings › About gains
  Website, Source code, Privacy policy and Open source licenses, which draws
  the bundled copy of `THIRD_PARTY.md` (kept equal to the root's by
  `VersionConsistencyTests`) with the LGPL notice and the version.
- **Six languages.** English, Bosnian, German, Spanish, French and Brazilian
  Portuguese in one String Catalog, read through the `L10n` funnel.
- **The architecture tests.** Import boundaries, the package graph, license
  headers, no suppressions, lint thresholds, tool and workflow pins, version
  consistency, the catalog, the theme tokens, view purity (V1 to V12) and
  navigation coverage, read from the tree.
- **CI and release lanes.** `ios-ci.yml` (format, strict lint, project drift,
  tests on a simulator, Release build), `security.yml` and `codeql.yml`,
  `version-consistency.yml`, and `release.yml` (App Store Connect signing when
  its six secrets exist, an unsigned `dish-X.Y.Z-unsigned.ipa` published also
  as `dish-ios.ipa` when they do not, Grype, SPDX and CycloneDX SBOMs, cosign
  keyless signatures, `SHA256SUMS` and SLSA L3 provenance).

[Unreleased]: https://github.com/TinkerNorth/dish-ios/commits/main
