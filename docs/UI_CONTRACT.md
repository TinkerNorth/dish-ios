# The UI contract

The iOS twin of dish-mac's `docs/UI_CONTRACT.md`: how the shell is put
together, what a page may and may not do, and the rules a kit component keeps.
The design handoff (boards, screen index, copy rules) is
[`design/README.md`](design/README.md); the tokens are in
[`../DESIGN.md`](../DESIGN.md); the dataflow rules behind all of it are in
[`ARCHITECTURE.md`](ARCHITECTURE.md). The shell, every page, the pair sheet
and the PC's page are built over the engine's live facts; what a test cannot
say, how it looks, is a `#Preview` per state.

## The shell

[`ShellView`](../Sources/Dish/UI/Shell/ShellView.swift) is the scene's one
content: a `TabView` of three `SwiftUI.Tab`s in the `sidebarAdaptable` style,
each its own `NavigationStack`, with the session accessory under the tab bar
and the covers over all of it. There is one window and no second scene. The
tab bar, the toolbars, the sidebar and the glass are iOS 26's own and are not
restyled. On an iPhone every screen is portrait but the play cover, which is
landscape; on an iPad every screen, the play cover included, follows the
device ("On an iPad" below).

Navigation is data.
[`NavigationMachine.swift`](../Sources/Dish/Navigation/NavigationMachine.swift)
is a pure reducer; [`NavigationStore`](../Sources/Dish/Navigation/NavigationStore.swift)
applies its events, runs its effects and hands the tab bar, each stack, the
cover and the sheets their bindings. Pages reach it as the `NavigationStore`
environment value and send it events; a view holds no `NavigationPath` or
`isPresented` of its own for app navigation.

| Event | Effect |
|---|---|
| `select(Tab)` | Switch the tab. A tap on the tab already on screen **pops it to its root**, as iOS does. |
| `push(Page)` | Push a page onto the tab on screen. |
| `show(Page, in: Tab)` | A tab's list opens one of its pages, alone on that tab's stack: on a phone the push from the list, on an iPad the page beside it, so a second row replaces the first rather than stacking on it. Controllers' rows and heart, and Connections' paired rows, send it. |
| `pop` | The page on top leaves: Forget pops the PC's page before the PC goes. |
| `pathChanged(Tab, [Page])` | A stack moved on its own (the back button, a swipe, a system pop): the state follows it. |
| `openSheet(Sheet)` | Raise a sheet over the tabs or the setup cover; refused over play and the dim. `pair(serverId:)` also starts the pairing (effect `beginPairing(serverId:)`). |
| `closeSheet` | Lower the sheet: Cancel, the X, a swipe down. A pair sheet's pairing is cancelled with it (effect `cancelPairing(serverId:)`). |
| `pairingChanged(serverId:)` | The model's pairing card opened on a satellite (a Pair, or a PC that asked for a PIN as it was connected to): the pair sheet shows it, in place of an address sheet. The card closed, paired or cancelled in the model: the pair sheet lowers with nothing left to cancel. |
| `openSetup(SetupEntry)` | Raise the setup cover over whatever covered the tabs, the dim included, and start the walk (effect `startSetup(entry)`). |
| `setupEnded(SetupEnding)` | Lower the setup cover, select Controllers and complete the welcome (effects `endSetup`, `markWelcomeComplete`). Both endings, `bound` and `skipped`, do the same. Ignored while no setup cover is up. |
| `dim` | Raise the dim cover. Ignored while any cover is up: the accessory that asks for it is not on screen under a cover. |
| `wake` | Lower the dim cover. Ignored unless the dim is up. |
| `coverDismissed` | The system lowered the cover (a swipe down, a scene change). Setup ends as a skip, the dim as a wake. |
| `connectTo(id:)` | Siri, Spotlight or Shortcuts' Connect to a PC (an App Intent, below): the model reaches for the PC (effect `connect(id:)`) and, while the tabs or the dim are on screen, the PC's page shows alone on Connections, the dim waking and a sheet going with its pairing. Under play or the setup walk nothing moves but the effect. |

The store also tells TipKit which hint the person no longer needs after
each event (`learnedHint(_:from:to:)`, "Hints" below): Support Dish
pushed, Add a controller opened or a walk that bound one, Stop gamepad,
the dim risen. An event the machine refused teaches nothing.

`SetupEntry` is `firstRun` (the welcome, then the three steps), `addController`
(straight to Input) and `guide` (Settings › Setup guide: the welcome again).
`Cover` is `setup(SetupEntry)`, `play(PlayScreen)` or `dim`; `Sheet` is
`pair(serverId:)` or `addByAddress`, and a cover rising or the setup cover
falling takes the sheet with it. On a first run
(`onboarding_welcome_completed` unset, read through `OnboardingPreferenceStore`
when the store is built) the store starts with the setup cover up and the walk
started, so the tabs never flash; a later launch starts on Controllers with no
cover.

The three tabs, in tab-bar order: **Controllers** (`gamecontroller`),
**Connections** (the antenna stand-in for the Satellite glyph) and **Settings**
(`gearshape`). The pushed pages are **Name on your PC** (`Page.deviceName`,
pushed from Settings), a **controller's page** (`Page.controller(id:)`,
pushed from a Controllers row), a **PC's page** (`Page.pcDetail(id:)`, pushed
from a paired Connections row), **Help & FAQ** (`Page.help`, from Settings ›
Setup & help), **Open source licenses** (`Page.licenses`, from Settings ›
About), **Support Dish** (`Page.support`, from the heart on the
Controllers toolbar and from Settings › About), **Diagnostics**
(`Page.diagnostics`, from Settings › Setup & help) and **Dead zones**
(`Page.deadZones(id:)`, from a controller's page). `NavigationCoverageTests` keeps the map whole.

### On an iPad

The app runs on the iPhone and the iPad (`TARGETED_DEVICE_FAMILY` 1,2). The
iPad shows the same shell, laid out from two facts the scene reads once and
hands down, never read in a view (V13):

- **The device**, `DeviceIdiom`, read by `DishScene` from
  `UIDevice.current.userInterfaceIdiom` through `deviceIdiom(_:)`, for the
  orientation lock alone. `screenOrientation(for:idiom:)` keeps an iPhone
  upright but for play, and lets an iPad turn every way on every screen:
  iPadOS 26 turns the window of an app that shares the screen with the
  device, whatever the app's mask says, and refuses it a programmatic turn
  (`UISceneErrorDomain` 101). `UIRequiresFullScreen`, deprecated in iPadOS
  26, would only letterbox a landscape window on an upright screen, so it is
  not used.
- **The window**, `WindowFacts` (`\.windowFacts`): SwiftUI's size class
  across and down, and whether the window is on its side, read by
  `WindowReader` (`Sources/Dish/Scene/WindowReader.swift`), the modifier the
  scene puts at the window's root.

What changes with them:

- **The tabs** are `sidebarAdaptable`: on an iPad they are a bar along the
  top that opens into a sidebar of the three tabs ("Toggle sidebar"); on an
  iPhone, the tab bar. The session accessory stays, along the bottom.
- **Controllers and Connections** split on a regular width
  (`tabLayout(_:width:)`): a `NavigationSplitView` in the balanced style,
  the tab's page as the list, and beside it the page the list opened, in a
  `NavigationStack` of its own for what that page pushes. The list selects
  (`List(selection:)` over `navigation.listSelection(of:)`, the first page of
  the tab's path); a selected row sends `show`, and the column's own pops
  stop at the opened page (`navigation.detailPath(of:)`). A row is selected
  rather than pushed and draws no chevron (`rowOpening(_:layout:)`); its
  Open, Pair and Connect buttons stay buttons. Before anything is opened
  the column invites a pick ("Pick a controller", "Pick a PC"), or stays
  blank while the list has nothing to open (`tabDetailState`). Settings, and
  every tab on a compact width (an iPad's narrow windows), keep their stack.
- **The setup cover** stands in a readable column `DishSize.setupColumn`
  wide on a regular width (`setupCoverState(facts:width:)`).
- **The play cover** fills the window on its side, the gamepad at the iPad's
  measures (`PadMetrics.regular`) where both size classes are regular; an
  iPhone Pro Max on its side is regular across but compact down and keeps
  the phone's. Upright, the gamepad keeps its landscape arrangement at the
  phone's measures in a band `DishSize.padUprightHeight` tall along the
  bottom, where the hands hold the iPad (`padLayout(_:)`). The touchpad and
  the mouse fill the window either way.
- **The sheets** are iPadOS's form sheets; the dim fills the screen.

### The session accessory

`SessionBar` (kit) is the `tabViewBottomAccessory`, drawn from one
`SessionBarState` that `sessionBarState(_:)` builds from `ShellFacts.session`.
`ShellView` attaches it only while that state is non-nil, because iOS 26.0 has
no `isEnabled:` form and an empty accessory still draws its glass. The session
is the live satellite carrying the most pads (`AppModel+Session.swift`).

- **Expanded**, with the tab bar at full height: the PC's name over
  "Streaming · 3 pads · 4 ms", a Dim button (moon) and a Play button (the
  on-screen gamepad). A `stoppedResponding` session, one whose heartbeat acks
  falter, draws "Stopped responding" in the error colour with a Reconnect
  button, the Connections tab wears a badge of 1 (`connectionsBadge`), and
  the controller rows bound to that PC say "Connection lost" (D4; the
  engine's `linkHealth` reads a faltering link as lost).
- **Inline**, while the tab bar is minimized (`.tabBarMinimizeBehavior(.onScrollDown)`):
  `SessionBar` reads `tabViewBottomAccessoryPlacement` and draws the short line
  alone, "3 pads · 4 ms", or the warning alone.
- A button whose closure is nil is left out. Dim sends `navigation.send(.dim)`;
  Play sends `openPlay(.gamepad)`; Reconnect calls `model.reconnect`, which
  closes the faltering session and opens it again. TipKit's dim hint points
  at Dim until the person has dimmed once ("Hints (TipKit)").

### The covers

All three are `fullScreenCover(item: navigation.cover)`, one presentation per
kind (`CoverIdentity`), so the pause menu moving between play screens keeps
its cover up; `ShellCover` switches on
the `Cover` case and `NavigationCoverageTests` requires a
`<Name>Cover.swift` for each.

- **Setup** (`Sources/Dish/UI/Setup/SetupCover.swift`): see "The setup cover"
  below. Skip is on the toolbar of every step, including the welcome.
- **Play** (`PlayCover.swift`, the screens in `Sources/Dish/UI/Play/`):
  `openPlay(screen)` raises it and starts the screen on the on-screen
  controller (effect `startPlay`); `closePlay`, Stop gamepad and a system
  dismissal lower it and release what it held (effect `endPlay`). A cover
  replacing another ends it. On an iPhone the scene locks the window to
  landscape while it is up (`screenOrientation(for:idiom:)`, the
  `OrientationLock` app delegate) and to portrait otherwise; an iPad's
  window follows the device ("On an iPad"). It is dark, hides the status bar and the
  system's overlays and defers the system's edge gestures. The gamepad, the
  touchpad and the mouse are drawn from `playCoverState`; each control is a
  kit component tracking its own finger (`PadButtons`, `PadSticks`,
  `TouchSurfaces`), so several fingers hold several controls; the touchpad's
  two fingers come from `SpatialEventGesture`. The pause menu is a native
  `Menu`: Resume, the other two screens, on the gamepad Motion (disabled
  with its reason), Rumble and Emulate as, and the destructive Stop gamepad,
  which TipKit's urgent hint on the pause button names until it is used.
  The dim is refused over play: its Dim lives on the accessory.
- **Dim** (`DimCover.swift`): `DishTheme.dimBackground` (true black in either
  appearance), `.statusBarHidden()`, `.persistentSystemOverlays(.hidden)`, the
  words "low power" and "tap to wake" in the eyebrow style, and a tap anywhere
  sends `.wake`. It is also an accessibility button with the same action. It
  draws the clock from `ShellFacts.now` (the dim runs the clock while it is
  up) and, while a session is up, the session card: the accessory's own
  line and each bound pad's level (`dimCoverState`). It is raised only by
  the accessory's Dim.

### The sheets

A sheet is `Sheet.pair(serverId:)` or `Sheet.addByAddress`, held by the
navigation state and drawn by `ShellSheet` (`Sources/Dish/UI/Sheets/`). Two
hosts present it: the tabs, through `navigation.tabsSheet`, while no cover is
up, and the setup cover, through `navigation.setupSheet`, while it is
(`presentedSheet(_:by:)` says which; neither presents over play or the dim).
A swipe down sets the binding to nil, which is `closeSheet`. The views hold
only what is theirs: the pair sheet the digits typed so far, the address
sheet its draft and whether the model refused it.

- **Pair with a PC** (`PairSheet`, B5): from Pair on a found or revoked row,
  Re-pair on a PC's page, a PC that wants a PIN on Pick your PC, and from the
  model itself when a PC connected to by address asks for one
  (`ShellView.onChange(of: pairingSheetId(model.openPairing))` sends
  `pairingChanged`). The card is `pairSheetState(pairing:serverId:deviceName:typed:)`
  over `model.openPairing`: the satellite's PIN typed into as many cells as
  the engine's PIN has (`pairingPinDigits`, the field over the cells sending
  a whole PIN through `submitPin`), the hint where it is on the PC, "or", the
  request card (this iPhone's code, "Waiting · 1:58", the time left of what
  the satellite keeps the request (the engine's `ApprovalPolling`) counted
  down as each approval poll moves the attempt's `elapsedMs`, with no line of
  its own for the expiry; approved;
  declined or expired with Try again, which is `newCode`), and Rename this
  iPhone, which edits the name through `renameThisIPhone` so the request is
  filed again under it. A refused PIN is worded on the card and clears the
  cells. The sheet lowers when the model's card closes: paired (on
  Connections the row reads paired; in setup the walk is on Review, which
  names the PC), or cancelled.
- **Add a PC by address** (`AddByAddressSheet`): from the plus on the
  Connections toolbar, from the primer and from Pick your PC (which also
  pick `.byAddress`). One field for the host or host:port, the default port
  named under it (`defaultSatelliteUdpPort`), and Connect, which calls
  `addByAddress`; a text that is not an IPv4 address is refused on the
  sheet, a failure of the attempt is worded from `lastConnectionEvent`
  (`connectionFailureText`, every `ConnectionFailure` case), and a PC that
  wants a PIN replaces the sheet with the pair sheet. `onAppear` sends
  `pageAppeared(.addByAddress)`, which clears the stale event.

### The scene

[`DishScene`](../Sources/Dish/DishScene.swift) is not a view. It builds
`AppModel` and `NavigationStore` once, injects both, passes down `settingsURL`,
`appVersion` and `thirdPartyNotice` (the values only UIKit and the bundles can
give, so no view reads UIKit or a bundle), sets `.preferredColorScheme` from
`shellFacts.preferences.appearance` through `colorScheme(for:)`, and sets
`UIApplication.shared.isIdleTimerDisabled` from `idleTimerDisabled(facts:)`
(a session is up and Keep screen on is set) in an `onChange`. It reads the
device's idiom once, gives the `OrientationLock` its first answer for that
device before UIKit asks (`follow(_:)`), turns the window as the cover
changes, and puts `WindowReader` at the window's root, the one reader of the
window's size classes and shape, which hands them down as `windowFacts`.
(a session is up and Keep screen on is set) in an `onChange`. It also turns
TipKit on (`TipKitTips.configure`, unless the defaults say `tips_hidden`),
hands the navigation store TipKit's `learned` and the model's `connect`,
and hands App Intents the `IntentRouter` they post through, once, from its
body (`AppDependencyManager.shared`, a host singleton read only here).

## Pages

A page is `Sources/Dish/UI/Pages/<Name>Page.swift`, with its rows or sections
as further `View` types in the same folder (`ControllersRows.swift`,
`ConnectionsRows.swift`, `SettingsSections.swift`). A page that is a tab root
is a thin view that reads `model.shellFacts`, builds its state with its mapper
and hands it to a `<Name>PageBody` that draws the state, so a preview can draw
any state without a model.

1. **One view state per page**, a struct (or an enum with a case for every
   condition) of rendered values: localized strings, `DishTheme` tokens, flags,
   chip models. It is built by a pure mapper in
   `Sources/Dish/UI/Mappers/<Name>Mappers.swift` that takes `words: L10n = .app`
   last, tested in `Tests/DishTests/Mappers/<Name>MappersTests.swift`, one test
   per flow (empty, content, each variant).
2. **A body is layout.** Layout, a `switch` over the view state, and intent
   calls. No string formatting, no `Date()`, no `UIPasteboard`, `UIApplication`,
   `UserDefaults`, `URLSession`, `Task.sleep`, and no engine lookups. Links open
   through SwiftUI's `openURL`; the Settings URL comes from the scene.
3. **Intents only.** A user action is a call on `AppModel` or an event to the
   `NavigationStore`.
4. **Lifecycle hooks forward.** `onAppear` and `onDisappear` call
   `model.pageAppeared(...)` and `model.pageDisappeared(...)` and nothing else;
   the Connections page runs the clock this way, and the Diagnostics page
   the source that re-reads the sessions' words, the pads' rates and the
   lock statistics once a second while it shows.
5. **Every word is an `L10n` property**, in `Sources/Dish/L10n/L10n+<Screen>.swift`.
6. **Use the system's controls.** `List` (`.insetGrouped`), `Section`, `Toggle`,
   `Picker`, `Menu`, `ContentUnavailableView` and toolbar items. No hard-coded
   list corner radius.

Today's pages and their mappers:

| Page | View state | Mapper | What it draws |
|---|---|---|---|
| `SettingsPage` | `SettingsPageState` | `settingsPageState(preferences:forwarding:appVersion:words:)` | THIS IPHONE (Name on your PC, pushing `deviceName`), WHILE STREAMING (Keep screen on, Dim screen after), FORWARDED FEATURES (the global switches: Motion, Rumble and Touchpad as `Toggle`s through `setMotionForwarded`, `setRumbleForwarded` and `setTouchpadForwarded`, and the Light bar as a `Picker` of Follow game and Off through `setLightbarMode`, each with its line under it, over every controller's own switches), SETUP & HELP (Setup guide, sending `openSetup(.guide)`; Help & FAQ and Diagnostics, each pushing its page), APPEARANCE (System, Light, Dark) and ABOUT (Support Dish with the heart, the version, Website, Source code and Privacy policy through `openURL`, and Open source licenses). |
| `DiagnosticsPage` | `DiagnosticsPageState` | `diagnosticsPageState(facts:appVersion:locale:timeZone:words:)` | DISH (the app version, the protocol this build speaks, the Local Network status), CONNECTIONS (a card per paired or pooled PC: its address and link tier, and while a session is up its protocol, epoch and controller bitmap against what was applied, the virtual-controller backend, the round trips, the missed heartbeats and the counters: sent, received, dropped and the replay guard), CONTROLLERS (a card per controller with its health as the dot and chip: its link, report and motion rates, type, battery, binding and its side of the wire), LOCK STATISTICS only in a `LOCK_STATS` build, and EVENTS (the flight recorder's newest thirty lines, newest first). Copy hands the whole transcript to the pasteboard through the model (`copyToPasteboard`), Share to a `ShareLink`; `onAppear` sends `pageAppeared(.diagnostics)`, which starts the source's 1 Hz tick, and `onDisappear` stops it. |
| `ControllersPage` | `ControllersPageState` (`ControllersContent`: `empty` or `list`) | `controllersPageState(controllers:apply:paired:words:)` | A list of controller rows (glyph tile, name, the destination line with a dot and the link word, battery) over a separate "Add a controller" button with its hint, which sends `openSetup(.addController)`; with no controllers, the invitation above the same button. A row pushes its controller's page; a pad Dish cannot read says "Not supported" and opens nothing. The bind in flight or failed for a pad (`ShellFacts.apply`) speaks on its row in place of the destination ("Applying binding…", or why it failed, in the error colour), which is where setup's Bind lands (B6). A long press offers the row's actions and a swipe the quickest of them (`ControllerRowState.actions`, "Row actions" below): Open for the on-screen controller, Unbind for a bound controller, or Bind to with each paired PC for an unbound one. The heart on the toolbar (`DishTheme.pulse`) pushes Support Dish; TipKit's hints point at the heart, once a controller is listed, and at Add a controller (`ControllersHints`). |
| `ConnectionsPage` | `ConnectionsPageState` (`title`, `add`, `ConnectionsContent`: `denied`, `empty`, `list`) | `connectionsPageState(facts:settingsURL:words:)` | PAIRED rows (online with the latency and the bound controllers, offline with when the PC was seen and Connect, needs pairing with Pair), each pushing the PC's page; FOUND ON <Wi-Fi> rows, each with Pair, and "Searching" in the header while a scan runs; the Moonlight hosts row (not tappable yet) and a footnote; the empty state; and, when Local Network is denied, "Dish can't see your network" with Open Settings through the scene's `settingsURL`. The plus on the toolbar opens Add a PC by address. `onAppear` sends `pageAppeared(.connections)`, which runs the clock and one scan. A PC that never advertised a name is known by its address (`connectionTitle`). A long press offers a row's actions and a swipe the quickest of them (`ConnectionRowState.actions`): a paired PC's Connect or Disconnect, Re-pair and Forget This PC, which asks first in the PC page's words (`ConnectionRowState.forget`), and a found PC's Pair. A pull on any state of the page, the empty ones included, looks again (`refreshConnections`) and lets go once the scan is in. |
| `DiagnosticsPage` | `DiagnosticsPageState` | `diagnosticsPageState(facts:appVersion:locale:timeZone:words:)` | DISH (the app version, the protocol this build speaks, the Local Network status), CONNECTIONS (a card per paired or pooled PC: its address and link tier; a Moonlight host's card reads its session's phase, its name and versions, the running app, the control round trip and a line per pad it holds; and while a satellite session is up its protocol, epoch and controller bitmap against what was applied, the virtual-controller backend, the round trips, the missed heartbeats and the counters: sent, received, dropped and the replay guard), CONTROLLERS (a card per controller with its health as the dot and chip: its link, report and motion rates, type, battery, binding and its side of the wire), LOCK STATISTICS only in a `LOCK_STATS` build, and EVENTS (the flight recorder's newest thirty lines, newest first). Copy hands the whole transcript to the pasteboard through the model (`copyToPasteboard`), Share to a `ShareLink`; `onAppear` sends `pageAppeared(.diagnostics)`, which starts the source's 1 Hz tick, and `onDisappear` stops it. |
| `ControllersPage` | `ControllersPageState` (`ControllersContent`: `empty` or `list`) | `controllersPageState(controllers:apply:words:)` | A list of controller rows (glyph tile, name, the destination line with a dot and the link word, battery) over a separate "Add a controller" button with its hint, which sends `openSetup(.addController)`; with no controllers, the invitation above the same button. A row pushes its controller's page; a pad Dish cannot read says "Not supported" and opens nothing. The bind in flight or failed for a pad (`ShellFacts.apply`) speaks on its row in place of the destination ("Applying binding…", or why it failed, in the error colour), which is where setup's Bind lands (B6). The heart on the toolbar (`DishTheme.pulse`) pushes Support Dish. |
| `ConnectionsPage` | `ConnectionsPageState` (`title`, `add`, `ConnectionsContent`: `denied`, `empty`, `list`) | `connectionsPageState(facts:settingsURL:words:)` | PAIRED rows (online with the latency and the bound controllers, offline with when the PC was seen and Connect, needs pairing with Pair), each pushing the PC's page; FOUND ON <Wi-Fi> rows, each with Pair, and "Searching" in the header while a scan runs; the Moonlight hosts row (not tappable yet) and a footnote; the empty state; and, when Local Network is denied, "Dish can't see your network" with Open Settings through the scene's `settingsURL`. The plus on the toolbar opens Add a PC by address. `onAppear` sends `pageAppeared(.connections)`, which runs the clock and one scan. A PC that never advertised a name is known by its address (`connectionTitle`). |
| `SettingsPage` | `SettingsPageState` | `settingsPageState(preferences:forwarding:appVersion:words:)` | THIS IPHONE (Name on your PC, pushing `deviceName`), WHILE STREAMING (Keep screen on, Dim screen after), FORWARDED FEATURES (the global switches), SETUP & HELP (Setup guide, sending `openSetup(.guide)`), APPEARANCE (System, Light, Dark) and ABOUT (Support Dish with the heart, the version, Website, Source code and Privacy policy through `openURL`, and Open source licenses). Diagnostics is not built and has no row. |
| `HelpPage` | `HelpPageState` | `helpPageState(words:)` | Walk me through setup (`openSetup(.guide)`), then CONCEPTS, BEST PERFORMANCE, TROUBLESHOOTING and ABOUT DISH as `DisclosureGroup`s, then LINKS. |
| `SupportPage` | `SupportPageState` (`SupportShelfState`: `loading`, `tips`, `unavailable`; `SupportNoticeState`: `none`, `thanks`, `note`) | `supportPageState(support:words:)` | The heart, the pitch, the three tips with StoreKit's own prices (`model.tip`), the outcome, and Restore purchases (`model.restoreTips`); `onAppear` sends `pageAppeared(.support)`, which loads the shelf. |
| `LicensesPage` | `LicensesPageState` (`LicensesContent`: `missing` or `notice`) | `licensesPageState(notice:appVersion:words:)` | The bundled `THIRD_PARTY.md`, handed down by the scene as `\.thirdPartyNotice`, then the LGPL notice and "Dish 0.1.0 · TinkerNorth · LGPL-3.0". |
| `ControllerPage` | `ControllerPageState` (`ControllerContent`: `pad` or `gone`) | `controllerPageState(controllers:paired:apply:pads:id:words:)` | C1: the status card (name, link, family, battery, the dot of the PC it sends to), BINDING with the destination (`BindingDestinationState`: the PC's name with its dot and Unbind, through `unbind(slotId:)`; or "Bind to" as a `Menu` of the paired PCs, through `bind(slotId:to:)`, with the hint to pair one first while there is none), the apply inline under it (`ApplyRowState`: "Applying binding…" with a spinner, "Binding applied", or why it failed with Try again, which binds to the same PC again) and Emulate as (a `Picker` through `setEmulatedType`; for a pad bound to a Moonlight host the protocol's Auto, Xbox, PlayStation and Nintendo through `setMoonlightEmulatedType`, with the line saying what Auto sends), FUNCTIONS (a `Toggle` per switch the pad has, through `setControllerFeature`; the Motion row carries a line under it, `MotionRowStatus`, worded from `motionIndicatorFor` and in the warning colour when the satellite is to blame) and the microphone and speaker footnote, then a Dead zones row that pushes `Page.deadZones(id:)` (left out for the on-screen gamepad) and TELEMETRY (`ControllerTelemetryState`: Gamepad, then Motion and Touch for a pad that has the hardware, each a rate in Hz off `shellFacts.diagnostics.pads`, the same `InputRateTracker` readings Diagnostics shows; drawn only once the pad has sent a report, the on-screen gamepad included). The page runs the source's tick while it shows, through `pageAppeared(.controller)`; the title is the pad's name and the subtitle "84% battery · USB-C". A pad that left while the page was open shows "This controller isn’t connected to your iPhone." |
| `PcDetailPage` | `PcDetailPageState` (`PcDetailContent`: `pc` or `gone`) | `pcDetailPageState(facts:id:words:)` | D2, a paired PC: the status card ("Online · 4 ms", when it was seen, or "Needs pairing", over "Satellite 2.1.11 · Protocol 3 · 192.168.1.24", with what is known), CARRYING · 2 OF 4 with each bound controller on its slot (or "Nothing bound yet"), WHAT CARRIES each way from the satellite's capabilities (motion while its backend is up, the return path while its feedback is; left out until probed), then Re-pair (the pair sheet), Disconnect while the session is up or Connect while the PC rests (neither while its key was revoked), and Forget This PC, a destructive `confirmationDialog` titled "Forget This PC" that names how many controllers stop streaming, pops the page and calls `forget`. A PC forgotten while its page was open shows "This PC is no longer remembered." under the generic title "PC". |
| `DeviceNamePage` | `DeviceNamePageState` | `deviceNamePageState(preferences:words:)` | A text field whose draft is the page's own `@State`, committed with `setDeviceName`. |
| `DeadZonesPage` | `DeadZonesPageState` (`DeadZonesContent`: `pad` or `gone`) | `deadZonesPageState(id:controllers:zones:words:)` | A controller's Dead zones: the stick and trigger dead zones as sliders over the desktops' 0 to 30 percent with a readout each, through `setStickDeadzone` and `setTriggerDeadzone` as they move, and Reset to defaults through `resetDeadzones`; the page's subtitle is the pad's name, and a pad that left shows "This controller isn’t connected to your iPhone." |
| `PairSheet` | `PairSheetState` (`card(PairCardState)` or `ended`) | `pairSheetState(pairing:serverId:deviceName:typed:words:)` | "The sheets" above: the cells, the request with its code, the outcomes and Rename this iPhone. |
| `AddByAddressSheet` | `AddByAddressSheetState` | `addByAddressSheetState(draft:rejected:connecting:lastEvent:words:)` | "The sheets" above: the field, the default port, Connect with its spinner, the refusal or the failure. |
| the shell | `[TabItemState]`, `SessionBarState?`, `TabLayout`, `RowOpening`, `TabDetailState` | `tabItems(facts:words:)`, `sessionBarState(_:words:)`, `tabLayout(_:width:)`, `rowOpening(_:layout:)`, `listSelection(_:layout:)`, `tabDetailState(_:opened:facts:words:)` | The tab titles, symbols and the Connections badge; the accessory's two shapes; on an iPad, which tabs split, what a row does in each layout, and the column beside a split's list. |

### Row actions and pull to refresh

A Controllers or a Connections row offers its actions under a long press
(`contextMenu`) and the quickest of them under a swipe (`swipeActions`).
Every one is a fact of the row's mapper, `RowActionsState` (the menu's
entries, an entry being an action or a submenu, and the actions each edge
reveals), drawn by the kit's `RowActions` modifier and handed to the page's
own `act`, which calls the same intents the controller's and the PC's pages
do. A row with nothing to offer has none.

| Row | Long press | Leading swipe | Trailing swipe |
|---|---|---|---|
| The on-screen controller | Open, then Unbind while bound | Open | Unbind, while bound |
| A pad, bound | Unbind | | Unbind |
| A pad, unbound | Bind to › each paired PC (none while nothing is paired) | | |
| A pad Dish cannot read | | | |
| A paired PC, online | Disconnect, Re-pair, Forget This PC | Disconnect | Forget This PC |
| A paired PC, resting | Connect, Re-pair, Forget This PC | Connect | Forget This PC |
| A paired PC whose key was revoked | Re-pair, Forget This PC | Re-pair | Forget This PC |
| A PC found on the network, or typed by its address and not yet paired | Pair | Pair | |

No swipe runs its action on its own (no full swipe), and a destructive one
wears `DishTheme.error` rather than the destructive role, which would
animate the row away before anything was decided. Forget This PC asks
first, in the same dialog the PC's page asks (the kit's `ForgetDialog`,
over `forgetState(bound:)`), and only the dialog's Forget calls `forget`.
Re-pair and Pair open the pair sheet, Connect and Disconnect call `connect`
and `disconnect`, Bind to and Unbind call `bind(slotId:to:)` and
`unbind(slotId:)`, and Open sends `openPlay(.gamepad)`.

Pull to refresh on Connections (`refreshable`) calls `refreshConnections`,
the person's own scan through the Local Network seam, which returns once
discovery has adopted the scan, so the spinner stays while it looks. The
empty and denied states sit in a scroll view that fills the page, so a pull
reaches them too, and a denied page learns that way that the person allowed
Local Network in Settings.

### The setup cover

`SetupCover` is a `NavigationStack` hosting one step at a time, chosen by
`setupCoverState(facts:)` from `ShellFacts.setup`, under the system toolbar:
a Back chevron when the walk can go back, the title "Set up Dish" with the
subtitle ("Input · 1 of 3", "Destination · 2 of 3", "Binding · 3 of 3"; the
middle dot is U+00B7), and Skip. The welcome has neither title nor subtitle.
The machine is `reduceSetup` in `DishCore` ([`ARCHITECTURE.md`](ARCHITECTURE.md),
"The setup machine"); each step is a view over its mapper's state, in
`Sources/Dish/UI/Setup/` and `Mappers/Setup*Mappers.swift`.

| Step | View | State | What it draws |
|---|---|---|---|
| Welcome | `WelcomeStep` | `WelcomeStepState` | The mark, the headline and intro, three features (bring the controller you own, or play on the screen, and it stays on your network), Continue, and "Get Satellite for your PC" through `openURL`. |
| Input · 1 of 3 | `InputStep` | `InputStepState` | Pads iOS already sees ("Found on this iPhone", each with Use; none today), then Wired controller (marked BEST), Bluetooth controller and On-screen gamepad. A pick moves on. |
| Destination · 2 of 3, the primer | `LocalNetworkStep` | `LocalNetworkStepState` | The phone and the PC over Wi-Fi, why Dish asks, Continue (which asks iOS) and "Add a PC by address", which picks `.byAddress` and opens the address sheet over the cover. Shown while the status is `.unknown`. Its Continue is what marks the primer seen (`local_network_primed`), which lets the Connections tab scan as it opens. |
| Destination · 2 of 3, Pick your PC | `PickPCStep` | `PickPCStepState` | Satellites (FASTEST), the Moonlight hosts (FAST), Add a PC by address, Get Satellite, and, when Local Network is denied, the refusal with Open Settings. A pick moves on; a satellite that wants a PIN (`SetupPCRow.pairServerId`) also opens the pair sheet over the cover, and Review waits under it. |
| Binding · 3 of 3 | `ReviewStep` | `ReviewStepState` | The pad and the PC (a PC added by address is named once it is paired, from `ShellFacts.addedByAddress`; until then "A PC by address", still to pair), Emulate as (DualSense, DualShock 4, Xbox Wireless, Switch Pro), the Motion switch, the Sends to PC and Gets back columns, and Bind. |

Skip and Bind each end the walk in the model and send `setupEnded`, which
lands on Controllers. Bind binds the pad the walk names, a pad iOS sees or
the on-screen gamepad, to the satellite it picked or added by address
(`AppModel+Setup.swift`, `bindDraft`); the apply then speaks on the
controller's row on the Controllers tab.

## App Intents

Siri, Spotlight and the Shortcuts app reach Dish through five App Intents
in `Sources/Dish/Intents/`: Open the gamepad, Open the touchpad, Open the
mouse, Dim the screen (`PlayIntents.swift`) and Connect to a PC
(`ConnectToPCIntent.swift`, with `PCEntity` and its `PCQuery` over the
paired PCs, each named as its Connections row names it). Each opens the
app (`supportedModes: .foreground`) and is one navigation event, which it
posts through `IntentRouter`, the seam the scene builds over its
`NavigationStore` and its model's paired PCs and hands to App Intents'
dependency manager: `openPlay(.gamepad)`, `.touchpad`, `.mouse`, `dim`
and `connectTo(id:)`. SwiftUI builds `DishScene` again on its own (a scene
phase change does) and keeps only the first build's `@State`, so the router
is a `@State` too and registers itself from the scene's body, which sees
the kept one, exactly once (`register(with:)`): a second registration while
an intent runs takes away the router the intent resolved, and the intent
traps. The machine's own rules hold, so a play screen ends
a walk it covers and the dim waits under a cover. The engine knows nothing
of the intents.

Three things a probe on the simulator showed decide where the pieces live:

- The App Shortcuts provider (`DishShortcuts`, a phrase and a short title
  per intent) lives in the app target, `App/Sources/DishShortcuts.swift`:
  App Intents drops a provider declared in a package when it merges the
  package's metadata into the app's. The intents it names are therefore
  `public`, the one exception to `DishScene` being the package's only
  public type besides `OrientationLock`.
- No `AppIntentsPackage` is declared on either side. The package's
  intents reach the app's metadata on their own, and an explicit
  `includedPackages` names a type the system looks for as a separate
  bundle's: with the package linked statically, `linkd` refuses the whole
  app ("did not match any imported symbol", then
  `aggregateMetadataIsEmpty`).
- The system reads the intents' words from the app bundle's own tables,
  never from the package's resource bundle, so they live in the app
  target's catalogs: titles, descriptions, the PC's type and parameter
  and the short titles in `App/Resources/Localizable.xcstrings`, and the
  phrases in `App/Resources/AppShortcuts.xcstrings`. They are literals
  App Intents extracts at build time, not `L10n` properties, and
  `AppIntentsLocalizationTests` holds them to the same rules as the
  funnel: every one in its catalog, nothing unused, every language,
  placeholders (`${applicationName}`, `${pc}`) intact.

The intents donate nothing: no `IntentDonationManager`, no
`NSUserActivity`, no indexed entity.

## Hints (TipKit)

Four TipKit hints point at controls the person might miss. Each is a
`Hint` (`HintMappers.swift`) worded by `hintState(_:)` into a `HintState`
(its name in TipKit's store, title, message, glyph, and whether it is
urgent), which the page's state carries and the view anchors with the kit's
`.hint(_:)` modifier, TipKit's own `popoverTip` over `HintTip`; no page
imports TipKit.

| Hint | Points at | Shown | Put to rest by |
|---|---|---|---|
| `supportDish` | The heart on the Controllers toolbar | Once a controller is listed | Support Dish pushed |
| `addController` | Add a controller | Always | Add a controller opened, or a walk that bound a controller |
| `stopGamepad` | The pause button | On play, even on a day another hint showed (urgent) | Stop gamepad |
| `dim` | The session accessory's Dim | While a session streams | The dim risen |

The scene turns TipKit on (`TipKitTips.configure`, at most one hint a day;
TipKit refuses a second configuration, which changes nothing, when SwiftUI
builds the scene again), and the navigation store tells it, through its
`learned` closure,
which hint each event put to rest (`learnedHint(_:from:to:)`). TipKit
keeps what was shown and closed on the device. The UI tests launch with
`-tips_hidden YES`, which leaves TipKit unconfigured, so no popover covers
what they tap.

## View purity

A view is layout. The scene hands the shell two objects, `AppModel` and
`NavigationStore`, and no engine object besides; everything else a page draws
is a published fact of the model (`shellFacts`), turned into the page's state
by its mapper. Every setter a page reaches is an intent: Settings' are in
`AppModel+Preferences.swift`, the setup cover's in `AppModel+Setup.swift`.

[`ViewPurityTests`](../Tests/ArchitectureTests/ViewPurityTests.swift) holds
every file under `Sources/Dish` that declares a `View` to these rules, line
by line (a whole-line comment is not code), exactly as the test implements
them; V13 holds every file under `Sources/Dish` but the scene's own:

| # | Rule | Caught by | Where |
|---|---|---|---|
| V1 | No clock | `Date()`, `TimelineView` | every view |
| V2 | No IO | `UIPasteboard`, `UIApplication`, `UserDefaults`, `URLSession`, `Bundle.main`, `UIDevice` | every view |
| V3 | No waiting | `Task.sleep`, `Timer.`, `DispatchQueue.` | every view |
| V4 | No subscriptions | `.sink(`, `withObservationTracking` | every view |
| V5 | No formatting | `String(format:`, `.formatted(`, any `...Formatter` | every view |
| V6 | Two objects observed | an `@Environment(Type.self)` of any type but `AppModel` and `NavigationStore`; `@Bindable`, `@ObservedObject`, `@StateObject` and `@EnvironmentObject` nowhere under `Sources/Dish` | every file under `Sources/Dish` |
| V7 | No engine objects | `localNetwork.`, `preferences.`, `onboarding.`, `appearance.`, `device.`, `streaming.`, `setupSource.`, `stores.` | every view |
| V8 | The model is facts and intents | `model.<name>` where `<name>` is neither a fact (a non-private `var` of an `AppModel` file) nor an intent (a `func` of one) | every view |
| V9 | No decision on the model | `if` / `guard` / `switch` over a `model.` fact, a ternary on `model....`, a lookup (`.first`, `.filter`, `.contains`, `.isEmpty`, `.count`, `.map`) on a fact; an intent's answer is the model's decision and passes | every view |
| V10 | No token picked | a ternary between `DishTheme` / `DishFont` tokens or `Color.clear` | pages |
| V11 | No boolean rules | `&&`, `\|\|` | pages |
| V12 | No fallback words | `??`, `.isEmpty ?` | pages |
| V13 | No window traits | `@Environment(\.horizontalSizeClass)`, `@Environment(\.verticalSizeClass)`, `userInterfaceIdiom` | every file under `Sources/Dish` but the scene and its seams (`DishScene.swift`, `Scene/`, `ShellEnvironment.swift`); a page takes `windowFacts` from the environment and hands it to its mapper |

"Pages" are every view but the components, which own their states (K2): the
kit and `Theme.swift`. A choice a page would have made is a mapper's: a colour
is a function returning the token (`destinationDot`, `connectionDot`), an
enablement rule a flag in the state (`ReviewStepState.motionEnabled`), a
fallback word the state's string (`deviceNameText`, which words "iPhone" when
the stored name is empty). `DishScene.swift` is the scene, not a view, and the sweep checks it
declares none; its seams under `Scene/` (the orientation lock, the window's
reader, a modifier) declare none either, and the environment keys it fills
are in `UI/Shell/ShellEnvironment.swift`, which declares no view.

[`NavigationCoverageTests`](../Tests/ArchitectureTests/NavigationCoverageTests.swift)
keeps the map whole: every `Tab` and `Page` case has its title worded in
`ShellMappers` (`tabTitle`, `pageTitle`), its `Sources/Dish/UI/Pages/<Name>Page.swift`,
its `Tests/DishTests/Mappers/<Name>MappersTests.swift` and a branch of the
shell's root or pushed switch, and every `Cover` case has its
`Sources/Dish/UI/Setup/<Name>Cover.swift` and a branch of the cover switch.

## Kit rules

A kit component lives in `Sources/Dish/UI/Kit/` and is drawn from any page's
state. The desktops' C1 to C8, adapted:

| # | Rule |
|---|---|
| K1 | **Two pages that would draw the same thing use a kit component.** One that has a variant is still a kit component. |
| K2 | **A kit component owns its own states.** A page never sets an opacity to say disabled or draws a pressed wash around one. |
| K3 | **A kit component never reads the domain.** It imports SwiftUI and Foundation only (and TipKit, for `HintTip` alone), reads no model from the environment and binds to none (`ImportBoundariesTests.testAKitComponentReadsNoDomain`); it takes values, tokens and closures, and the page hands it its state. |
| K4 | **One name per colour.** A tinted colour is its own `DishTheme` token, never a token times an alpha (`ThemeTokenTests.testAViewDerivesNoColourFromAToken`). |
| K5 | **Colours stay tokens.** A component passes `Color` tokens through and never builds one from components or hex (`ThemeTokenTests.testAViewWritesNoRawColour`). |
| K6 | **Every state a component can be in is reachable from a mapper test.** A state no test builds is not shipped. |
| K7 | **Tokens only.** A kit component sets no raw spacing, padding, corner, frame or glyph size: each is a `DishSize` or `DishSpace` token (`ThemeTokenTests.testAKitComponentSetsNoRawSize`, which rejects a digit after `spacing`, `cornerRadius`, `width`, `height`, `size`, `minLength`, `minWidth`, `minHeight`, `lineWidth` or `.padding(`). |
| K8 | **A glyph is never recoloured by state inside the component.** `RowGlyph` takes its tint and fill as values from the mapper's state; state colour lives in the dot and the chip. |

Today's kit: `Chip` (BEST, FASTEST, FAST; a tone is `success` or `primary`),
`RowGlyph` (the rounded tile at the head of a row), `SessionBar` (the
session accessory, with its inline form and the dim's hint), `PinCells` (a
PIN's digits in a row of cells, the caret's cell in the focus colour; the
field over it owns the typing), `RowActions` (a row's long-press menu and
swipes over its `RowActionsState`), `ForgetDialog` (Forget This PC's
question, asked by the PC's page and a Connections row), `HintTip` with
`.hint(_:)` (a hint as TipKit's popover), and the play screens' controls:
`FaceButton`, `RoundPadButton`, `ShoulderButton`, `HoldPanel`,
`PadStickControl`, `TriggerRail`, `DirectionPad`, `MovePad`, `ScrollStrip`,
`TwoFingerSurface` and `PlayPill`, each reporting its own finger in its own
units (a held flag, an offset in radii, a position across the surface) for
the page to turn into the reducer's event. `PadStickControl`, `FaceButton`,
`DirectionPad` and `TriggerRail` take their measures as values (a stick's
base and thumb, a face's diameter, an arm's side, a rail's breadth), which
the gamepad hands them from `PadMetrics`: the phone's, or an iPad's on its
side. `SectionEyebrow` and `StatusDot` live
in `Theme.swift` and follow the same rules. The setup chrome's own pieces are
in `UI/Setup/SetupKit.swift` and are host views, not kit: they are built from
a step's state and may use the environment's `openURL`.

## Keyboard

No shortcuts of Dish's own. On an iPad with a keyboard the system's own
focus moves through the sidebar and a split's list, which selects with it
like a tap. VoiceOver labels are part of the views (the Dim and Play buttons
name themselves, the glyph tiles hide from VoiceOver, the dim is an
accessibility button), and every row text is a Dynamic Type style.
