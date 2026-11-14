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

The shell, the protocol core, the controller bridge, the network engine,
Moonlight hosts, the play screens, Help, Support, Licenses, Diagnostics, the
pair sheet, the Connections rows and the PC's page are built, on the iPhone and
the iPad: a Satellite or a Moonlight host is found, paired with from a row, from
setup or by its address, bound to a pad or the on-screen gamepad, and streamed
to. The rows answer a long press and a swipe, Siri and Shortcuts can open the
play screens, dim and connect, and TipKit points at what a new person might
miss. `Tests/PARITY.md` lists everything not built.

### Added

- **Room on the wire for a controller's extra buttons.** `[wire-coordinated]`
  Protocol 4. Dish now speaks Satellite protocol 4: on a session that settled
  on it, every controller report carries a second word for the buttons an
  Xbox pad does not have, and a controller that sends them says so in its
  capabilities, shown as "Extra buttons" on Diagnostics. An older Satellite
  keeps working at protocol 3 and is sent exactly what it was sent before.
- **An Xbox Elite controller's back paddles reach the PC.** On a Satellite
  that speaks protocol 4, the four paddles of an Xbox Elite Wireless
  Controller Series 2 travel in that word under the names SDL gives them: P1
  and P2 are the right hand's upper and lower paddles, P3 and P4 the left
  hand's. iOS addresses the paddles only while the controller is on its
  default profile; on any other profile they press the buttons they are
  mapped to. Not yet tried with a real Elite.
- **The DualSense Edge is a controller type.** Every Emulate as picker lists
  the DualSense Edge last: the DualSense with two back buttons and two Fn
  buttons, which is where an Xbox Elite's four paddles land in a game. It is
  never picked for you, and on a Satellite that does not offer it the pad is
  emulated as a DualSense. Not yet tried against a host that offers the type.
- **A Steam Controller paired over Bluetooth is a controller.** Turn on
  Settings › Steam Controllers › Read over Bluetooth and a Steam Controller
  paired in Settings › Bluetooth, the 2015 model or the 2026 one, shows up in
  Controllers out of its keyboard-and-mouse mode, the way it does on Android
  and the Mac: its buttons, sticks, triggers, gyro, back buttons and grips
  reach the PC, its trackpads are the right stick, the touchpad or off on its
  page (the 2015 model's right trackpad is the right stick until you pick
  otherwise, the 2026 model's are the touchpad when the type it is emulated
  as has one), and the 2026 model rumbles. iOS never offers these
  controllers to apps, so Dish reads them over Bluetooth itself; the switch
  is off on a fresh install, turning it on is what asks for Bluetooth, and
  the row says when Bluetooth is off, refused or missing. The controller
  reports no battery over Bluetooth, so the PC is sent the iPhone's. Turning
  the switch off gives each controller its keyboard and mouse back. Not yet
  tried with either controller.

### Changed

- **A controller's battery on the PC is the lower of the controller's and
  the iPhone's.** The battery Dish sends a Satellite or a Moonlight host for
  a controller is now the lower of the controller's own charge and the
  iPhone's or iPad's, with the charging state of whichever is lower; a
  controller that reports no battery sends the iPhone's, and an unknown
  level loses to any known one. A wired controller that reports its charge
  is treated like any other. The controller's row, its page and Diagnostics
  still show the controller's own battery. The simulator reports no battery
  for the iPhone, so there every controller sends its own.

### Fixed

- **CI reads its iPad back before the UI tests run on it.** The iPad lane
  created its simulator and trusted `simctl bootstatus`; on one runner the
  device was gone a minute later and xcodebuild listed no simulator at all,
  on another the UI test runner timed out before any test ran, and each cost
  the whole run. `scripts/ci-simulator.sh` now creates the iPad on the newest
  runtime that supports it, requires `simctl list` to show it booted after
  the boot and again right before xcodebuild (recreating it when it is not),
  and runs xcodebuild once more only on those two runner errors, never on a
  failing test.
- **The UI tests wait for what the app ends in, not for a clock.** On a
  slow CI runner the iPad lane failed when a five-second wait for the
  Add a PC by address sheet ran out, and when the "Searching" label of
  a scan had already gone by the time the test looked for it. Every wait
  in `App/UITests` is now an expectation on a state the app reaches,
  with a shared patience of thirty seconds that ends the moment it is
  met: a scan is read on Diagnostics, where it leaves the Local Network
  allowed (and not asked yet while no scan ran), a sheet's lowering is
  waited for, and the two polls that slept are expectations too.
- **The Settings test holds the Rumble switch until the switch takes the
  press.** On GitHub's iPhone the test sometimes lost a flip of Rumble: the
  tap landed on the switch itself and reached the app, but lifted before
  the switch's press had begun, so the switch ignored it and the test
  failed thirty seconds later. A switch takes a touch only once its press
  has begun, about a frame after the touch lands, and XCUITest's tap lifts
  after 50 ms, which a slow runner's simulator sometimes needs more than.
  Each flip now holds the switch for half a second.
- **The on-screen gamepad sends its PC the iPhone's battery.** The
  on-screen gamepad bound to a Satellite or a Moonlight host sent no battery
  at all, where dish-android's sends the phone's. It now sends the iPhone's
  or iPad's charge and charging state every 30 seconds while it is among the
  controllers, like a controller with no battery of its own, and a Moonlight
  host is told at arrival that it has one.
- **The scene builds its objects once.** SwiftUI calls the scene's
  initializer again on its own (at launch and on a scene phase change) and
  keeps only the first build's state; each extra call used to build a whole
  model, which reached for the remembered PCs, and a navigation store, then
  threw them away. The scene now holds its root in `OnFirstUse`, which makes
  it the first time the kept build reads it, so a process makes one.

### Added

- **The iPad.** Dish runs on the iPad as well as the iPhone, turning every
  way on every screen. The tabs open into a sidebar from the bar along the
  top; Controllers and Connections draw their list beside the controller's
  or the PC's page, with "Pick a controller" and "Pick a PC" before one is
  picked, while Settings keeps its stack; setup stands in a readable column;
  the play screens fill the screen, the gamepad's sticks, faces, trigger
  rails and d-pad larger on an iPad on its side, and along the bottom when
  the iPad is held upright, since iPadOS will not turn it for play. The
  device and the window's size classes are read by the scene alone and
  handed down as facts. CI runs the UI tests again on an iPad Pro 11-inch
  (M5), and `scripts/ci-local.sh` does the same.

- **Row actions and pull to refresh.** A long press on a Controllers row
  offers Open for the on-screen controller, Unbind for a bound controller or
  Bind to each paired PC for an unbound one; on a Connections row, Connect or
  Disconnect, Re-pair and Forget This PC for a paired PC and Pair for a found
  one. A swipe offers the quickest of them and never runs one on its own, and
  Forget This PC still asks first. Pulling Connections down looks for PCs
  again, the empty and denied pages included, and lets go once the scan is in.
  On an iPad, where a pull does not reach the list column's refresh, Scan
  sits beside Add in that column's toolbar.
- **App Intents.** Open the gamepad, Open the touchpad, Open the mouse, Dim
  the screen and Connect to a PC, for Siri, Spotlight and the Shortcuts app,
  each an App Shortcut with its phrase in all six languages. Connect to a PC
  offers the paired PCs and shows the one picked on its page. The intents
  donate nothing.
- **Hints.** TipKit points at the heart once a controller is listed, at Add
  a controller (pads pair in Settings › Bluetooth), at the pause button's
  way out of play and at the accessory's Dim, at most one a day, and each
  goes once the person has done what it points at.
- **The parity sweep.** Bindings survive a restart: a pad's binding to a
  Satellite (`wifi_binding_list`) or a Moonlight host
  (`moonlight_binding_list`) is remembered when it is made, kept when the
  pad leaves, and put back without you when the pad returns and its PC is
  known; Unbind and Forget This PC erase it, and the on-screen gamepad is
  put back once it is listed. The controller page's Motion row says why
  motion does or does not reach the PC, from the Satellite's own answer to
  the last apply. Diagnostics gives each Moonlight host a card beside the
  Satellites': its session, name and versions, running app, control round
  trip and each pad it carries. A pad bound to a Moonlight host offers the
  protocol's Auto, Xbox, PlayStation and Nintendo under Emulate as, with the
  line saying what Auto sends.
- **The second parity sweep.** The controller page shows TELEMETRY once the
  pad has sent a report, the on-screen gamepad included: the Gamepad rate,
  and the Motion and Touch rates for a pad that has the hardware, off the
  same readings Diagnostics shows, ticking only while the page is on screen.
  A Dead zones page, pushed from a controller's page, tunes the stick and
  trigger dead zones with Reset to defaults, and Settings gains Forwarded
  features: the global Motion, Rumble, Touchpad and Light bar switches that
  sit above every controller's own. The pair sheet counts the request down
  ("Waiting · 1:58") as the approval poll runs, and no longer says how many
  minutes the satellite keeps it. A PC added by its address is a found row
  with Pair, titled by the address, from the moment it is added, and Review
  names it that way until pairing names it. The Connections tab scans as it
  opens only once the setup primer was seen (`local_network_primed`), so iOS
  asks its Local Network question after the explanation. On an iPad the
  words that name the iPhone name the iPad, in all six languages, and a
  device with no name of its own introduces itself to the satellite as
  "iPad".
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

- **Moonlight hosts: a pad can now be bound to Sunshine, Apollo or Wolf.**
  The Connections tab's Moonlight hosts row opens their page: the hosts a
  `_nvstream._tcp` scan finds or an address names, each with its trust word,
  its session's state and the way out of it, the app its session starts, and
  Forget behind a menu that asks first. Pairing is the protocol's own: Dish
  shows a PIN in the host's row, the person types it into the host's page, and
  the five phases run under the RSA identity Dish mints once in the Keychain,
  over mutual TLS with the host's certificate pinned. A host carries up to four
  pads in one session, opened when the first is bound and handed back when the
  last leaves; input rides the ENet control stream sealed with AES-GCM, and the
  host's rumble and light come back to the pad. Ported from dish-mac under its
  names, pinned by Wolf's vectors, proved end to end against a loopback host,
  and held to its own lock laws.

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
  consistency, the catalog, the theme tokens, view purity (V1 to V13) and
  navigation coverage, read from the tree.
- **CI and release lanes.** `ios-ci.yml` (format, strict lint, project drift,
  tests on a simulator, Release build), `security.yml` and `codeql.yml`,
  `version-consistency.yml`, and `release.yml` (App Store Connect signing when
  its six secrets exist, an unsigned `dish-X.Y.Z-unsigned.ipa` published also
  as `dish-ios.ipa` when they do not, Grype, SPDX and CycloneDX SBOMs, cosign
  keyless signatures, `SHA256SUMS` and SLSA L3 provenance).

[Unreleased]: https://github.com/TinkerNorth/dish-ios/commits/main
