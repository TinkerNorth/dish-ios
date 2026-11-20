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

Nothing yet.

## [1.1.0] - 2026-11-19

### Added

- **The controller database.** Dish ships the fleet's controller database
  (dbVersion 1, 272 records, served from
  `https://dish.tinkernorth.com/controllers/v1/`) and checks the website
  for a newer copy ten seconds after launch and every six hours while it is
  in the foreground: the manifest with `If-None-Match`, then, only for a
  newer version, the controller list and its strings in each language, each
  file checked against the manifest's size and SHA-256 before it replaces
  the cached copy whole. The requests carry no query and no identifier.
  Settings › Controller database carries "Check for controller updates
  automatically", on by default, and "Check now"; with the switch off no
  request leaves the device and Check now is not offered.
- **A Steam Controller's record on its page and its card.** A Steam
  Controller read over Bluetooth shows, on its page and on its Diagnostics
  card, the database's record: its name, its id, its verification as a
  chip, and the known issues filed for Bluetooth on this device. A pad
  GameController reads shows nothing from the database, since iOS names no
  USB or Bluetooth ids to an app.
- **The controller data in Diagnostics.** The App section gains the
  version in force and where it came from (built in or downloaded), the
  built-in version, and when the last check ran and how it ended.
- **Report a problem, and Ask a question.** Diagnostics gains Report a
  problem and Ask a question, one screen in two categories: pick what it is
  about (controller not recognised, no rumble or feedback, connection or
  latency, audio, something else, a question), write what happened and what
  you expected, and pick the controller it concerns, preselected to a pad
  connected now. The screen lists in plain words what the file will hold,
  Preview file shows the file itself, and Continue in Mail opens a message to
  support@tinkernorth.com in your own mail app, under
  `Dish support: <category> · Dish for iOS <version> on <model>`, with your
  words first, then the page's summary, and the file attached; where no mail
  account is set up, the share sheet takes the file. Nothing is sent until
  you press Send. The file, `dish-diagnostics-dish-ios-<yyyyMMdd-HHmmss>.json`
  (the fleet's `dish-diagnostics.v1` bundle), holds your report; the app and
  its build; the device model, iOS version, battery, thermal state and Low
  Power Mode; the controller data; every controller, the on-screen one
  included, with its record, its path (`gameController`, `bluetooth`,
  `virtual`), the frames it published, their rate and the last one, and what
  reached each feedback lane with the last command; each PC as "Host 1",
  "Host 2" with the session as this iPhone sees it (each slot with the
  backend and result the PC answered, the last heartbeat ack, the round
  trips, and the datagrams sent and received by kind) and, from a Satellite
  of 2.3.0 or later with a session up, that PC's own snapshot of the
  connection, asked for over the authenticated client with a two-second
  wait; an older Satellite, told by the version its capabilities gave and
  never asked, or one that does not know the connection, refuses the proof
  or does not answer in time, leaves the capabilities the app already
  fetched and the reason, every answer naming the PC by its alias alone,
  and a Moonlight host its serverinfo version, never its name; and the
  flight recorder. The file never holds pairing keys,
  fingerprints, addresses, Wi-Fi names or the names of your PCs.

- **The on-screen controller is always listed.** As Android's Virtual
  Controller is: one of the controllers from the first launch, bound and
  unbound from its row and its page like any pad, its binding kept across
  restarts; Open raises its gamepad once a PC is bound to it, and Stop
  gamepad closes the screen and keeps the binding.
- **The low-power countdown.** Settings › Dim screen after now does what it
  says: while a session streams and the tabs are on screen, the seconds
  without a touch on the phone count up to the delay, the last five on the
  session accessory as "Low power in 5 s", and the dim rises on its own.
  A touch anywhere restarts the count; controller input never does, as on
  Android. The dim also drops the screen's brightness to its floor and
  gives it back on wake. The accessory's Dim still dims at once.
- **Find a PC and Reconnect.** A controller with no PC paired offers Find a
  PC, straight to the Connections tab, instead of an empty Bind to; a pad
  whose PC is lost offers Reconnect ahead of Unbind on its row and page.
- **The touchpad and the mouse per controller.** A pad with no touchpad of
  its own, bound to a satellite that grants mouse control, offers Open
  touchpad and Open mouse on its row and under its status card: the phone's
  surface is sent through that pad's own slot, which asks the host for the
  mouse while the screen is open. The on-screen controller's own mouse
  screen asks the same way, so it moves the PC's pointer.
- **The Lightning note.** An iPhone or iPad with a Lightning port cannot
  host a controller over a plain cable, so on one the Controllers tab (while
  nothing is listed), setup's Input step and Add a controller's hint say that
  a wired pad needs Apple's Lightning to USB Camera Adapter; the wired row
  wears an ADAPTER chip in place of BEST, Help & FAQ gains "My wired
  controller doesn't show up", an attached pad's link reads Lightning rather
  than USB-C, and the note opens a Wired on this iPhone sheet that draws the
  adapter between the phone and the controller, lists the three steps and
  links Apple's page. iOS names no port to an app, so the scene reads the
  hardware's model identifier once and the engine maps it; a device the
  table does not know reads as USB-C and sees no note.
- **The last write to a Steam Controller, in the support file.** The
  file's rumble lane carries `lastWrite` for a Steam Controller Dish
  reads over Bluetooth: the route (`gattWrite`), the report id, the value as
  Dish gave it to Bluetooth in hex, whether Bluetooth answered the write
  and with which error, and when it was written. A pad GameController
  reads has `lastWrite` null, since the framework writes and Dish never
  sees the bytes. The record is kept on the Steam links' own queue with no
  lock and no allocation in a write; the report reads it once.
- **Tests for the controller database's languages.** de-AT reads German,
  bs-Latn-BA Bosnian, pt-PT and pt-BR Brazilian Portuguese, fr-CA French,
  es-419 Spanish, en-GB English and ja-JP English, and a key one language
  leaves out reads in English for that key alone.


### Changed

- **The play screens' way out is a back button.** The pause menu and its
  button are gone; a back chevron beside the PC pill closes the gamepad,
  the touchpad or the mouse and keeps the on-screen controller's binding,
  as Android's overlays leave. Motion, Rumble and Emulate as live on the
  controller's page, and the on-screen controller's other screens open from
  its row and its page: Open mouse once the satellite grants mouse control
  on a session that is up. The hint on the pause button goes with it.
- **L3 and R3 are sticks of their own.** Beside each stick, a smaller
  stick at seven tenths of its size, as Android's skin has them: a finger
  landing on it presses the stick's button and its movement tilts the
  stick, so one press clicks and aims at once, and lifting lets go of both.
  They were round buttons.
- **The gamepad carries its touchpad.** Emulating a DualShock 4, a
  DualSense or a DualSense Edge, the gamepad draws the pad's touchpad at
  its top centre, where the real ones carry it: one or two fingers stream
  as the pad's, and a tap on it (still, within 0.2 s) clicks it for a
  hundred milliseconds, as Android's skin does. An Xbox or Switch Pro pad
  has none.
- **The mouse and the touchpad wear their glyphs.** A mouse beside Mouse on
  the mouse screen and in Open mouse, the touchpad's beside Touchpad, as
  Android's overlays and card actions show them.
- **Every step of a link shows.** A PC being reached for reads
  "Connecting…" with a spinner on its row and page, with Cancel; one that
  stopped responding reads so in the error colour with Reconnect, on the
  row, the page and the accessory alike; a pad bound to a PC being reached
  for says so on its row, its page and the play pill.
- **A failed attempt is worded where it happened.** Why an attempt you made
  on a PC failed stays on its row and page, in the error colour, until the
  next attempt or until the PC is up, with Connect or Pair to try again; a
  silent retry says nothing. The address sheet's spinner and error are the
  engine's facts about the typed PC.
- **The accessory shows a PC coming back.** Your own reach for a PC that
  carries pads shows on every tab with a spinner until it is up; the
  Connections badge counts every PC that needs you, a key revoked or an
  attempt failed included.
- **Updating while the PC applies a pad.** A switch flipped or Emulate as
  picked on a bound pad shows "Updating…" on the pad's page and its edit
  page while the PC takes it.
- **The facts come in slices.** Each page reads the slice it maps, so it
  re-renders for that alone; Diagnostics alone reads the whole.
- **A controller's row carries its actions; its page is its settings.**
  A Controllers row draws what the controller offers under its line, as
  Android's card does (Open gamepad, Open touchpad, Open mouse, Reconnect,
  Bind to, Find a PC); its long-press menu and swipes offer the same. A tap
  opens the controller's settings: BINDING, Emulate as, Functions, Dead
  zones, Telemetry and Unbind at the foot.
- **A blocked data path and a taken session are named.** A session that
  opens but never hears an ack back, the silence a hotspot that keeps
  devices apart or a firewall leaves, says so on the PC's row, its page
  and the accessory, with Reconnect; so does a session another device took
  over. A silent retry that fails because the PC is off still says nothing.
- **A bind fails as soon as its reach does**, instead of waiting out its
  budget.
- **A pad can be sent to another PC from its page.** The destination row
  opens the PCs whose link is up, the current one checked. Bind to, on the
  page, the row and the long press alike, offers only those; with none up it
  is Find a PC, and the footer says what to do on the Connections tab.
- **Every control answers the finger.** A pressed tile, capsule or round
  button washes over its own surface and shrinks a little; a pressed row
  washes its whole cell; the wash leaves slowly enough for a tap to show; a
  pointer highlights a control on an iPad and a disabled one fades:
  Material's state layers, as one kit style and one kit row. On an iPad,
  the row a split's detail shows is tinted. Nothing uses the silent plain
  or borderless styles, a NavigationLink or a Link any more, and setup's
  cards sit on the surface colour like every other list.
- **The screen stays awake only for a pad.** Keep screen on holds the
  phone awake only while a session streams with a pad bound; a bare
  connection lets it lock like any other app.
- **Low power waits for a pad.** The countdown arms only while a session
  streams with a pad bound, never for a bare connection, one being brought
  back, or one that stopped responding.
- **The session accessory keeps Dim and loses Play.** The on-screen
  controller is a controller with its own Open now, so the accessory no
  longer opens its gamepad.
- **The play screens rise and fall without the cover's slide.** The slide
  fought the window's turn to landscape and back; now the turn is the one
  motion.

### Fixed

- **The screen stays on only for an active binding.** Dish holds the
  screen on exactly while a session streams with a binding that is active,
  a pad iOS lists or the on-screen controller while its screen is up, and
  Keep screen on is set (`screenHeld`). A PC that stopped answering, a bare
  connection, a session being brought back and a binding whose pad is away
  let the phone lock like any other app; before, a stopped PC and a
  remembered binding kept it awake.
- **The low-power countdown runs wherever the screen is held.** As on
  Android, the count to Settings › Dim screen after runs on every screen
  while the screen is held, the play screens, the setup walk and the sheets
  included; the gamepad's pill reads "Low power in 5 s" as the accessory
  does, and the dim lies over the screen instead of replacing it, so a
  dimmed gamepad goes on streaming and a touch anywhere lands back on it.
- **A play control reads the finger the moment it lands.** The gamepad's
  faces, shoulders, L3, R3, View, Guide and Menu, its sticks, rails and
  d-pad, the mouse's buttons, strip and pad and the touchpad's surface and
  click zones take their touches from a view of UIKit's own over each
  control (`Fingers.swift`), not from a `DragGesture`, which on a device
  waited for the finger to move before a button answered and, with another
  finger on the stick, kept a tapped A pressed until the next touch on it
  lifted. A button stays held until its last
  finger lifts, a stick or a rail follows the first finger that landed and
  the next once it lifts, the touchpad's two slots come from the same
  fingers, the scroll strip no longer sends a sample for a finger that only
  landed, and the face diamond's place-holding cells no longer take a strip
  off the bottom of Y, X and B.
- **The scene builds its objects once.** SwiftUI calls the scene's
  initializer again on its own (at launch and on a scene phase change) and
  keeps only the first build's state; each extra call used to build a whole
  model, which reached for the remembered PCs, and a navigation store, then
  threw them away. The scene now holds its root in `OnFirstUse`, which makes
  it the first time the kept build reads it, so a process makes one.

## [1.0.0] - 2026-11-15

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

- **A failed Settings test no longer fails the next run.** The UI tests
  read Rumble as on and Steam Controllers over Bluetooth as off, a fresh
  install's switches, but the simulator kept whatever a run left: one that
  failed between two flips of Rumble left it off, and every later run on
  that simulator failed at its first check. CI starts each run on a new
  simulator, so only a reused one showed it. Every launch now starts the
  two switches at a fresh install's values, as it already does the Local
  Network primer.
- **iOS asks for the local network in your language.** The question iOS
  puts before Dish first looks for Satellite on your Wi‑Fi was in English
  whatever the iPhone's language. It is now in Bosnian, German, Spanish,
  French and Brazilian Portuguese too, as the Bluetooth question is.
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

[Unreleased]: https://github.com/TinkerNorth/dish-ios/compare/1.1.0...main
[1.1.0]: https://github.com/TinkerNorth/dish-ios/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/TinkerNorth/dish-ios/releases/tag/1.0.0
