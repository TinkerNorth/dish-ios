# The UI contract

The iOS twin of dish-mac's `docs/UI_CONTRACT.md`: how the shell is put
together, what a page may and may not do, and the rules a kit component keeps.
The design handoff (boards, screen index, copy rules) is
[`design/README.md`](design/README.md); the tokens are in
[`../DESIGN.md`](../DESIGN.md); the dataflow rules behind all of it are in
[`ARCHITECTURE.md`](ARCHITECTURE.md). This is wave 1: the shell is built and
every state of every page is built, but the engine's controllers, connections
and session are empty, so several states are reachable only through a mapper
test or a `#Preview`.

## The shell

[`ShellView`](../Sources/Dish/UI/Shell/ShellView.swift) is the scene's one
content: a `TabView` of three `SwiftUI.Tab`s, each its own `NavigationStack`,
with the session accessory under the tab bar and the covers over all of it.
There is one window and no second scene. The tab bar, the toolbars and the
glass are iOS 26's own and are not restyled. iPhone only, portrait only but
for the play cover, which is landscape only.

Navigation is data.
[`NavigationMachine.swift`](../Sources/Dish/Navigation/NavigationMachine.swift)
is a pure reducer; [`NavigationStore`](../Sources/Dish/Navigation/NavigationStore.swift)
applies its events, runs its effects and hands the tab bar, each stack and the
cover their bindings. Pages reach it as the `NavigationStore` environment value
and send it events; a view holds no `NavigationPath` or `isPresented` of its
own for app navigation.

| Event | Effect |
|---|---|
| `select(Tab)` | Switch the tab. A tap on the tab already on screen **pops it to its root**, as iOS does. |
| `push(Page)` | Push a page onto the tab on screen. |
| `pathChanged(Tab, [Page])` | A stack moved on its own (the back button, a swipe, a system pop): the state follows it. |
| `openSetup(SetupEntry)` | Raise the setup cover over whatever covered the tabs, the dim included, and start the walk (effect `startSetup(entry)`). |
| `setupEnded(SetupEnding)` | Lower the setup cover, select Controllers and complete the welcome (effects `endSetup`, `markWelcomeComplete`). Both endings, `bound` and `skipped`, do the same. Ignored while no setup cover is up. |
| `dim` | Raise the dim cover. Ignored while any cover is up: the accessory that asks for it is not on screen under a cover. |
| `wake` | Lower the dim cover. Ignored unless the dim is up. |
| `coverDismissed` | The system lowered the cover (a swipe down, a scene change). Setup ends as a skip, the dim as a wake. |

`SetupEntry` is `firstRun` (the welcome, then the three steps), `addController`
(straight to Input) and `guide` (Settings › Setup guide: the welcome again).
`Cover` is `setup(SetupEntry)` or `dim`. On a first run
(`onboarding_welcome_completed` unset, read through `OnboardingPreferenceStore`
when the store is built) the store starts with the setup cover up and the walk
started, so the tabs never flash; a later launch starts on Controllers with no
cover.

The three tabs, in tab-bar order: **Controllers** (`gamecontroller`),
**Connections** (the antenna stand-in for the Satellite glyph) and **Settings**
(`gearshape`). The pushed pages are **Name on your PC** (`Page.deviceName`,
pushed from Settings), a **controller's page** (`Page.controller(id:)`,
pushed from a Controllers row), **Help & FAQ** (`Page.help`, from Settings ›
Setup & help), **Open source licenses** (`Page.licenses`, from Settings ›
About), **Support Dish** (`Page.support`, from the heart on the
Controllers toolbar and from Settings › About) and **Diagnostics**
(`Page.diagnostics`, from Settings › Setup & help). `NavigationCoverageTests` keeps the map whole.

### The session accessory

`SessionBar` (kit) is the `tabViewBottomAccessory`, drawn from one
`SessionBarState` that `sessionBarState(_:)` builds from `ShellFacts.session`.
`ShellView` attaches it only while that state is non-nil, because iOS 26.0 has
no `isEnabled:` form and an empty accessory still draws its glass. There is no
session source yet, so today the accessory never appears.

- **Expanded**, with the tab bar at full height: the PC's name over
  "Streaming · 3 pads · 4 ms", a Dim button (moon) and, when wired, a Play
  button. A `stoppedResponding` session draws "Stopped responding" in the error
  colour with a Reconnect button, and the Connections tab wears a badge of 1
  (`connectionsBadge`).
- **Inline**, while the tab bar is minimized (`.tabBarMinimizeBehavior(.onScrollDown)`):
  `SessionBar` reads `tabViewBottomAccessoryPlacement` and draws the short line
  alone, "3 pads · 4 ms", or the warning alone.
- A button whose closure is nil is left out. Dim sends `navigation.send(.dim)`;
  Play sends `openPlay(.gamepad)`; Reconnect is nil until the session wave
  wires it (`Tests/PARITY.md`).

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
  replacing another ends it. The scene locks the window to landscape while
  it is up (`screenOrientation(for:)`, the `OrientationLock` app delegate)
  and to portrait otherwise. It is dark, hides the status bar and the
  system's overlays and defers the system's edge gestures. The gamepad, the
  touchpad and the mouse are drawn from `playCoverState`; each control is a
  kit component tracking its own finger (`PadButtons`, `PadSticks`,
  `TouchSurfaces`), so several fingers hold several controls; the touchpad's
  two fingers come from `SpatialEventGesture`. The pause menu is a native
  `Menu`: Resume, the other two screens, on the gamepad Motion (disabled
  with its reason), Rumble and Emulate as, and the destructive Stop gamepad.
  The dim is refused over play: its Dim lives on the accessory.
- **Dim** (`DimCover.swift`): `DishTheme.dimBackground` (true black in either
  appearance), `.statusBarHidden()`, `.persistentSystemOverlays(.hidden)`, the
  words "low power" and "tap to wake" in the eyebrow style, and a tap anywhere
  sends `.wake`. It is also an accessibility button with the same action. It
  draws the clock from `ShellFacts.now` (the dim runs the clock while it is
  up) and, while a session is up, the session card: the accessory's own
  line and each bound pad's level (`dimCoverState`). It is raised only by
  the accessory's Dim.

### The scene

[`DishScene`](../Sources/Dish/DishScene.swift) is not a view. It builds
`AppModel` and `NavigationStore` once, injects both, passes down `settingsURL`,
`appVersion` and `thirdPartyNotice` (the values only UIKit and the bundles can
give, so no view reads UIKit or a bundle), sets `.preferredColorScheme` from
`shellFacts.preferences.appearance` through `colorScheme(for:)`, and sets
`UIApplication.shared.isIdleTimerDisabled` from `idleTimerDisabled(facts:)`
(a session is up and Keep screen on is set) in an `onChange`.

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
| `ControllersPage` | `ControllersPageState` (`ControllersContent`: `empty` or `list`) | `controllersPageState(controllers:words:)` | A list of controller rows (glyph tile, name, the destination line with a dot and the link word, battery) over a separate "Add a controller" button with its hint, which sends `openSetup(.addController)`; with no controllers, the invitation above the same button. A row pushes its controller's page; a pad Dish cannot read says "Not supported" and opens nothing. The heart on the toolbar (`DishTheme.pulse`) pushes Support Dish. |
| `ConnectionsPage` | `ConnectionsPageState` (`denied`, `empty`, `list`) | `connectionsPageState(facts:settingsURL:words:)` | PAIRED and FOUND ON <Wi-Fi> sections, the Moonlight hosts row (not tappable yet) and a footnote; the empty state; and, when Local Network is denied, "Dish can't see your network" with Open Settings. The status never leaves `.unknown` today, so only the empty state is reachable at run time. |
| `SettingsPage` | `SettingsPageState` | `settingsPageState(preferences:appVersion:words:)` | THIS IPHONE (Name on your PC, pushing `deviceName`), WHILE STREAMING (Keep screen on, Dim screen after), SETUP & HELP (Setup guide, sending `openSetup(.guide)`; Help & FAQ and Diagnostics, each pushing its page), APPEARANCE (System, Light, Dark) and ABOUT (Support Dish with the heart, the version, Website, Source code and Privacy policy through `openURL`, and Open source licenses). |
| `DiagnosticsPage` | `DiagnosticsPageState` | `diagnosticsPageState(facts:appVersion:locale:timeZone:words:)` | DISH (the app version, the protocol this build speaks, the Local Network status), CONNECTIONS (a card per paired or pooled PC: its address and link tier, and while a session is up its protocol, epoch and controller bitmap against what was applied, the virtual-controller backend, the round trips, the missed heartbeats and the counters: sent, received, dropped and the replay guard), CONTROLLERS (a card per controller with its health as the dot and chip: its link, report and motion rates, type, battery, binding and its side of the wire), LOCK STATISTICS only in a `LOCK_STATS` build, and EVENTS (the flight recorder's newest thirty lines, newest first). Copy hands the whole transcript to the pasteboard through the model (`copyToPasteboard`), Share to a `ShareLink`; `onAppear` sends `pageAppeared(.diagnostics)`, which starts the source's 1 Hz tick, and `onDisappear` stops it. |
| `HelpPage` | `HelpPageState` | `helpPageState(words:)` | Walk me through setup (`openSetup(.guide)`), then CONCEPTS, BEST PERFORMANCE, TROUBLESHOOTING and ABOUT DISH as `DisclosureGroup`s, then LINKS. |
| `SupportPage` | `SupportPageState` (`SupportShelfState`: `loading`, `tips`, `unavailable`; `SupportNoticeState`: `none`, `thanks`, `note`) | `supportPageState(support:words:)` | The heart, the pitch, the three tips with StoreKit's own prices (`model.tip`), the outcome, and Restore purchases (`model.restoreTips`); `onAppear` sends `pageAppeared(.support)`, which loads the shelf. |
| `LicensesPage` | `LicensesPageState` (`LicensesContent`: `missing` or `notice`) | `licensesPageState(notice:appVersion:words:)` | The bundled `THIRD_PARTY.md`, handed down by the scene as `\.thirdPartyNotice`, then the LGPL notice and "Dish 0.1.0 · TinkerNorth · LGPL-3.0". |
| `ControllerPage` | `ControllerPageState` (`ControllerContent`: `pad` or `gone`) | `controllerPageState(controllers:id:words:)` | C1 without the PC half: the status card (name, link, family, battery), BINDING with "Destination · Not bound" (disabled) and Emulate as (a `Picker` through `setEmulatedType`), FUNCTIONS (a `Toggle` per switch the pad has, through `setControllerFeature`) and the microphone and speaker footnote; the title is the pad's name and the subtitle "84% battery · USB-C". A pad that left while the page was open shows "This controller isn’t connected to your iPhone." |
| `DeviceNamePage` | `DeviceNamePageState` | `deviceNamePageState(preferences:words:)` | A text field whose draft is the page's own `@State`, committed with `setDeviceName`. |
| the shell | `[TabItemState]`, `SessionBarState?` | `tabItems(facts:words:)`, `sessionBarState(_:words:)` | The tab titles, symbols and the Connections badge; the accessory's two shapes. |

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
| Destination · 2 of 3, the primer | `LocalNetworkStep` | `LocalNetworkStepState` | The phone and the PC over Wi-Fi, why Dish asks, Continue (which asks iOS) and "Add a PC by address". Shown while the status is `.unknown`. |
| Destination · 2 of 3, Pick your PC | `PickPCStep` | `PickPCStepState` | Satellites (FASTEST), the Moonlight hosts (FAST), Add a PC by address, Get Satellite, and, when Local Network is denied, the refusal with Open Settings. A pick moves on. |
| Binding · 3 of 3 | `ReviewStep` | `ReviewStepState` | The pad and the PC, Emulate as (DualSense, DualShock 4, Xbox Wireless, Switch Pro), the Motion switch, the Sends to PC and Gets back columns, and Bind. |

Skip and Bind each end the walk in the model and send `setupEnded`, which
lands on Controllers. Nothing is sent to a PC by Bind in this wave.

## View purity

A view is layout. The scene hands the shell two objects, `AppModel` and
`NavigationStore`, and no engine object besides; everything else a page draws
is a published fact of the model (`shellFacts`), turned into the page's state
by its mapper. Every setter a page reaches is an intent: Settings' are in
`AppModel+Preferences.swift`, the setup cover's in `AppModel+Setup.swift`.

[`ViewPurityTests`](../Tests/ArchitectureTests/ViewPurityTests.swift) holds
every file under `Sources/Dish` that declares a `View` to these rules, line
by line (a whole-line comment is not code), exactly as the test implements
them:

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

"Pages" are every view but the components, which own their states (K2): the
kit and `Theme.swift`. A choice a page would have made is a mapper's: a colour
is a function returning the token (`destinationDot`, `connectionDot`), an
enablement rule a flag in the state (`ReviewStepState.motionEnabled`), a
fallback word the state's string (`deviceNameText`, which words "iPhone" when
the stored name is empty). `DishScene.swift` is the scene, not a view, and the sweep checks it
declares none; the environment keys it fills are in
`UI/Shell/ShellEnvironment.swift`, which declares no view either.

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
| K3 | **A kit component never reads the domain.** It imports SwiftUI and Foundation only, reads no model from the environment and binds to none (`ImportBoundariesTests.testAKitComponentReadsNoDomain`); it takes values, tokens and closures, and the page hands it its state. |
| K4 | **One name per colour.** A tinted colour is its own `DishTheme` token, never a token times an alpha (`ThemeTokenTests.testAViewDerivesNoColourFromAToken`). |
| K5 | **Colours stay tokens.** A component passes `Color` tokens through and never builds one from components or hex (`ThemeTokenTests.testAViewWritesNoRawColour`). |
| K6 | **Every state a component can be in is reachable from a mapper test.** A state no test builds is not shipped. |
| K7 | **Tokens only.** A kit component sets no raw spacing, padding, corner, frame or glyph size: each is a `DishSize` or `DishSpace` token (`ThemeTokenTests.testAKitComponentSetsNoRawSize`, which rejects a digit after `spacing`, `cornerRadius`, `width`, `height`, `size`, `minLength`, `minWidth`, `minHeight`, `lineWidth` or `.padding(`). |
| K8 | **A glyph is never recoloured by state inside the component.** `RowGlyph` takes its tint and fill as values from the mapper's state; state colour lives in the dot and the chip. |

Today's kit: `Chip` (BEST, FASTEST, FAST; a tone is `success` or `primary`),
`RowGlyph` (the rounded tile at the head of a row), `SessionBar` (the
session accessory, with its inline form), and the play screens' controls:
`FaceButton`, `RoundPadButton`, `ShoulderButton`, `HoldPanel`,
`PadStickControl`, `TriggerRail`, `DirectionPad`, `MovePad`, `ScrollStrip`,
`TwoFingerSurface` and `PlayPill`, each reporting its own finger in its own
units (a held flag, an offset in radii, a position across the surface) for
the page to turn into the reducer's event. `SectionEyebrow` and `StatusDot` live
in `Theme.swift` and follow the same rules. The setup chrome's own pieces are
in `UI/Setup/SetupKit.swift` and are host views, not kit: they are built from
a step's state and may use the environment's `openURL`.

## Keyboard

Not applicable: iPhone only. VoiceOver labels are part of the views (the
Dim and Play buttons name themselves, the glyph tiles hide from VoiceOver, the
dim is an accessibility button), and every row text is a Dynamic Type style.
