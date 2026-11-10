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

The shell, the protocol core, the controller bridge, the network engine, the
play screens, Help, Support and Licenses, the pair sheet, the Connections
rows and the PC's page are built: a PC is found, paired with from a row, from
setup or by its address, bound to a pad or the on-screen gamepad, and streamed
to. `Tests/PARITY.md` lists everything not built.

### Added

- **Pairing and connections.** The pair sheet (B5), from Pair on a found or
  revoked row, from Pick your PC, from Re-pair on a PC's page and from a PC
  that asks for a PIN as it is connected to: the satellite's PIN typed into
  four cells and "Accept on your PC" with this iPhone's code, both at once,
  the outcomes worded (declined or expired with Try again, a refused PIN,
  a changed identity, another version), and Rename this iPhone. The
  Connections rows live (D1): paired PCs online with their latency and
  controllers, offline with when they were seen and Connect, or with Pair
  once the PC revoked the key; the PCs found on the Wi-Fi with Pair; a scan
  as the tab opens; and the plus that adds a PC by its address, in one
  field with the default port named under it. The PC's page (D2): the status
  card with the satellite's version and protocol, what it carries each way,
  the controllers it carries on their slots, Re-pair, Disconnect or Connect,
  and Forget This PC, which asks first. The session accessory's Reconnect,
  the Connections badge and "Connection lost" on the rows of a PC that
  stopped responding (D4). The controller page's Binding: the PC with
  Unbind, or Bind to a paired PC, with the apply drawn inline and on the
  Controllers row where setup's Bind lands. Setup's Bind now binds the
  on-screen gamepad and a PC added by address like any pad. Every failure
  the engine reports has its words.
- **The network engine: the engine can now find, pair with and stream to a
  Satellite.** A Bonjour browse for `_satellite._udp` that also reads the
  Local Network permission (iOS asks at the first scan, after setup's
  primer); pairing both ways at once, the operator's approval of a client
  PIN and the satellite's PIN typed in, with the key in the Keychain and the
  satellite's certificate pinned on first contact; the declarative session
  with up to four pads per satellite on the lowest free index, the per-slot
  converge while live, reconcile, re-key, close-notify and the backoff; the
  encrypted UDP data plane, a bound pad's report sealed and sent on its own
  queue with no lock, and the satellite's rumble, light bar, adaptive
  triggers and player LEDs back to the pad bound to their index; the facts
  for the paired and found PCs, the session and each controller's
  destination; setup's Bind binding the pad it names. Ported from dish-mac
  under its names, driven by its in-process `FakeSatellite`, and verified
  against the real satellite binary by `scripts/e2e_local.sh` and the
  `e2e.yml` lane. The `lock-stats` job in `ios-ci.yml` runs the lock laws.

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
  it. It shows the clock and, while a session is up, the session card with
  each bound pad's level.
- **The protocol core.** `DishCore` carries protocol 3 as dish-mac does, under
  the same file and type names: the constants (ports 9443, 9876 and 9879,
  `_satellite._udp`), the wire codecs for the pad, motion, touchpad and
  feedback frames and the packet envelope (`Wire/`), the session crypto (HKDF
  and ChaCha20-Poly1305 over CryptoKit) and the policy reducers the sessions
  need (close-notify, backoff, reverse pairing's cadence, TOFU, protocol
  negotiation, the capability solver, slot reconcile, apply progress, the
  latency window and the link tier). Every codec and the crypto are pinned by
  the fleet's cross-repo vectors.
- **The controller bridge.** Every pad GameController attaches reaches its own
  `PadFeed` on its own handler queue: the processor applies the deadzones, the
  feed holds its route (a `PadSink` and a slot, or none) in a mailbox the main
  actor writes and the queue reads without a lock, and the return paths
  (rumble, light bar, adaptive triggers, player LEDs) and the battery flow
  back through the same seam. The Controllers tab lists the attached pads
  live, Input's "Found on this iPhone" fills, and each controller has its
  page with everything but its PC binding. `LockLawTests` pins which thread
  may take which lock.
- **The play screens.** The on-screen gamepad (trigger rails, shoulders, two
  sticks, the d-pad, the faces labelled for the emulated pad, L3 and R3), the
  touchpad (one or two fingers and two click zones) and the mouse (Left, a
  Scroll strip, Right and the move pad), each a landscape cover with the
  status bar and the system's overlays hidden and its edge gestures held
  back; the pause menu (Resume, the other screens, Motion, Rumble, Emulate as,
  Stop gamepad). The on-screen controller is a controller slot of its own: it
  is listed on the Controllers tab with Open, its touches leave through its
  feed as they happen, a lost edge heals with three resends 50 ms apart and a
  keepalive a second (Android's pacing), its motion comes from the iPhone's
  sensors and its rumble plays on the Taptic Engine.
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
- **Diagnostics.** Settings › Setup & help › Diagnostics shows what the app
  sees right now: each paired PC's session as its heartbeat acks tell it
  (protocol, epoch and controllers against what was applied, the
  virtual-controller backend, the round trips, the missed heartbeats) with
  the data plane's counters (sent, received, dropped and the replay guard)
  and the link tier; each controller's report and motion rates, health,
  type, battery, binding and its side of the wire; the Local Network status
  and the app and protocol versions; the lock statistics in a `LOCK_STATS`
  build; and a log of this run (links appearing, changing and going, pads
  attaching, binding, unbinding and detaching), kept in memory only. Copy
  puts the whole page on the pasteboard and Share hands it to the share
  sheet. The satellite client now counts the datagrams it opens and refuses
  beside the ones it sends.
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
