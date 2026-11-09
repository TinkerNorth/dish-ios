# Parity: dish-ios against the other Dish clients

> **What this is.** The feature-parity ledger for this client, kept as a small
> matrix. **A pull request that changes a row updates this file in the same
> change**, and a reviewer checks the row. Coverage is not mapped here: the
> suites under `Tests/` are the coverage truth and CI runs them on every push.
> Deferred work lives here, never in a `TODO` comment.
>
> Legend: **built** works as the row says · **mapper only** the state is built
> and tested through its mapper and shown in a `#Preview`, but nothing reaches
> it at run time yet · **not yet** not built; the row says where it lands ·
> **n/a** does not apply on iOS. Verified against the code on 2026-11-09.
>
> This is wave 1, the shell. The engine publishes real but empty facts (no
> controllers, no connections, no session, a Local Network status that stays
> unknown), so the next waves only wire sources.

## 1. What is built in wave 1

| Feature | Status | Where |
|---|---|---|
| iOS 26.0 floor, iPhone only, portrait only, Swift 6 strict concurrency, Observation, no dependencies | built | `Package.swift`, `project.yml`; `PackageGraphTests` |
| Three tabs, each its own `NavigationStack`; navigation as data | built | `Navigation/NavigationMachine.swift`, `NavigationStore.swift`; `NavigationMachineTests`, `NavigationStoreTests`, `NavigationCoverageTests` |
| The session accessory with its inline form | mapper only: it is attached only while a session exists, and no source publishes one | `UI/Kit/SessionBar.swift`, `ShellMappers.swift`; `ShellMappersTests` |
| Setup: Welcome, Input (1 of 3), the Local Network primer and Pick your PC (2 of 3), Review and bind (3 of 3); Skip lands on Controllers | built; the pads and PCs it lists are empty today, and Bind records the request and sends nothing | `DishCore/Setup/SetupMachine.swift`, `UI/Setup/`, `Mappers/Setup*Mappers.swift`; `SetupMachineTests`, `Setup*MappersTests`, `AppModelSetupTests` |
| The low-power dim cover (black, tap to wake) | built; its only trigger is the accessory's Dim, so unreachable at run time | `UI/Setup/DimCover.swift`; `NavigationMachineTests` |
| Settings: Name on your PC, Keep screen on, Dim screen after, Setup guide, Appearance, version | built | `UI/Pages/Settings*.swift`, `DeviceNamePage.swift`; `SettingsMappersTests`, `DeviceNameMappersTests` |
| Empty Controllers and Connections pages | built | `ControllersPage.swift`, `ConnectionsPage.swift`; `ControllersMappersTests`, `ConnectionsMappersTests` |
| Preference stores under the fleet's keys (`theme_mode`, `onboarding_welcome_completed`) and the iOS keys (`device_name`, `keep_screen_on`, `dim_after_seconds`) | built | `DishEngine/Preferences/`; the store tests |
| Light, dark and system appearance | built; System by default (section 3) | `AppearancePreferenceStore`, `colorScheme(for:)` |
| Six languages (en, bs, de, es, fr, pt-BR) through the `L10n` funnel | built; `%lld s` and `%lld min` carry no plural forms (section 2) | `Sources/Dish/L10n/`, `Localizable.xcstrings`; `LocalizationTests` |
| Views are layout: one state per page from a pure mapper, intents only | built | `ViewPurityTests` (V1 to V12), `NavigationCoverageTests` |
| Keep screen on while a session streams | mapper only: `idleTimerDisabled(facts:)` is true only with a session | `ShellMappers.swift`; `ShellMappersTests` |

## 2. Not yet, one row each

| Feature | Where it lands |
|---|---|
| **GameController bridge.** `ShellFacts.attachedPads` and `controllers` are empty, so Input offers no "Found on this iPhone" pad and Controllers is always the empty state. | `DishEngine/Input/`, the wave that reads `GCController`; it fills `attachedPads` and `controllers` and ports the pad family detection (`EmulatedPad`) |
| **The controller page and tappable rows.** Controller rows draw but do nothing when tapped; there is no per-controller page (rename, Unbind, dead zones, switches). | `Page.controller(id:)` in `NavigationMachine.swift`, `UI/Pages/ControllerPage.swift` and its mapper tests, with the bridge |
| **Bonjour discovery behind the `LocalNetworkAccess` seam.** `RecordedLocalNetworkAccess` records asks and scans; its status never leaves `.unknown`, so the Local Network denied state (Connections and Pick your PC) is unreachable at run time, `found` and `scanning` stay empty and iOS never shows its permission prompt. The Info.plist already declares `_satellite._udp` and `_nvstream._tcp`. | a `DishEngine/Network` implementation of `LocalNetworkAccess`; the app swaps it in `AppModel`'s convenience initializer |
| **Pairing: the pair sheet, both paths, and the PC detail page.** Connection rows are not tappable; there is no pair sheet (the operator's approval and the typed PIN), no Forget This PC, no PC detail page. | `DishEngine/Network` (`PairingClient`, the connection store, the Keychain key store) and `UI/Pages/ConnectionPage.swift`, the pair sheet as a `Cover`/sheet case in the navigation machine |
| **The binding behind `BindingRequests`, and the apply overlay.** Bind records the draft in memory and sends nothing; there is no apply progress, no Unbind. | the binding wave: `DishEngine/Network` sends the session PUT; `BindingRequests` is replaced by the real coordinator and the apply overlay lands in `UI/Kit/` |
| **The wire protocol and the hot path.** The codecs, the session crypto and the policy reducers are in `DishCore`, pinned by the cross-repo vectors; no socket opens and nothing calls them yet: protocol 3, ports 9443 and 9876 and the beacon on 9879 are not touched. The rules to carry are dish-mac's: no lock, no allocation and no main-actor hop on the send path, the controller's own `handlerQueue`, `IP_TOS = 0xB8` and `SO_NOSIGPIPE` on every send, the kernel never on that path. | `DishCore` for codecs and crypto (pinned by the cross-repo vectors), `DishEngine/Network` for sockets and REST; see `docs/contract.md` |
| **Session facts.** No source publishes `ShellFacts.session`, so the accessory hides; Play is not wired (the accessory draws Dim alone), Reconnect is not wired, and the Connections badge for a stopped session never shows. | the session wave: `AppModel+Session.swift` with `reconnect()`, and the play screens for Play |
| **The play screens: gamepad, touchpad, mouse**, landscape, and the pause menu. The app is portrait only. | `UI/Play/` and an orientation change in `Info.plist` and `project.yml` for the play cover only |
| **The dim's session card and clock.** The cover draws "Low power", "Tap to wake" and a footnote only. | `DimCover.swift` with the session facts |
| **Support Dish.** StoreKit tips, so there is no heart button and no tips page. | `UI/Pages/SupportPage.swift`, a StoreKit seam in `DishEngine`, and the heart token the design names |
| **Help & FAQ.** Settings has no row for it. | `UI/Pages/HelpPage.swift`, pushed from Settings › Setup & Help |
| **Diagnostics.** Settings has no row for it. | `UI/Pages/DiagnosticsPage.swift` and a diagnostics source in `DishEngine` |
| **Licenses and About links.** Settings › About shows the version only. | a licenses page fed from `THIRD_PARTY.md`, and the About links, pushed from Settings |
| **Add a PC by address.** The primer and Pick your PC offer it and Review words it ("A PC by address"), but the pick leads to a binding with no address entry. | an address form in the setup cover and on the PC list, with `DishEngine/Network` |
| **The Moonlight hosts page.** The Connections row is not tappable. | `UI/Pages/MoonlightHostsPage.swift`, pushed from Connections |
| **Long-press menus, swipe actions, pull to refresh.** No row has a context menu or a swipe action, and no list refreshes. | with the pages that own the actions (Unbind, Forget This PC, Rescan) |
| **iPad, App Intents, TipKit.** iPhone only; no intents; no tips. | later waves; `TARGETED_DEVICE_FAMILY` in `project.yml` moves with iPad |
| **The kernel's other primitives.** Only `StateSource` is ported. `Composer`, `Controller`, `Repository` and `AsyncState` are not. | `Sources/DishKernel/`, each with its tests, in the wave that first needs it |
| **The e2e lane and the bench.** There is no loopback end-to-end against the real satellite, no bench and no measurements job. | `scripts/e2e_local.sh` and an `e2e.yml` workflow once the wire exists; `tools/bench/` with the hot path |
| **App Store signing secrets and export compliance.** The six secrets are not set, so `release.yml` ships an unsigned IPA; the Info.plist carries no `ITSAppUsesNonExemptEncryption` answer, which App Store Connect asks once the wire's encryption ships. | repository secrets and variables, and `App/Info.plist` |
| **Plural forms for `%lld s` and `%lld min`.** The two duration words are plain keys, so a language whose plural of a unit differs would show the wrong form. | the catalog and `LocalizationTests`, which would require the forms |
| **The custom satellite glyph.** An SF Symbol antenna (`satelliteSymbol`) stands in on the tab, the accessory and a Satellite PC's row. | an asset in `Media.xcassets` and `DishImage`, replacing `satelliteSymbol`; rendered as PNGs by `scripts/render-icon.sh`, as the mark is, since the asset catalog drops SVG masks |
| **A lock-free bounded queue (Vyukov's).** Not built, on purpose. The satellite (`core/log_queue.h`), dish-linux and dish-windows (`src/core/thread/MpscQueue.h`, the speaker playout) and dish-android (`mpmc_ring.h`: the bridge reports, the speaker frames, the USB acks) each carry one; dish-mac carries none, and the iOS hot path is dish-mac's: each pad's reports leave `sendto` on that pad's own `handlerQueue` under a compare-exchange send gate, a route change crosses to the hot path through a single-slot mailbox and atomic words, and a return command keeps only the newest of its kind. None of those is a many-producers-one-consumer hand-off, and the two consumers that justify a ring on the siblings do not exist on iOS: apps get no pad speaker, and there is no USB output lane without the Direct path. | port the desktops' `MpscQueue` (refuse when full, count the drop; not Android's drop-oldest ring) into `DishCore` over `Synchronization.Atomic<UInt64>` cells with trivially copyable items, with tests for FIFO order across producers, a refused push on a full queue and the drop count, only when a lane needs several producers feeding one consumer: the Direct path's USB output and acks, or a flight recorder written from the hot path. A mailbox or a direct send stays the first choice. |

## 3. Permission-gated APIs the later waves need

Apple grants these on request, so each wave that needs one asks early and
ships without it until it is granted; the code keeps the feature behind a seam
so the sanctioned path works alone.

| Capability | What needs it | Until it is granted |
|---|---|---|
| `com.apple.developer.networking.multicast` | Listening for the satellite's legacy UDP discovery beacon on 9879, or any broadcast or multicast send. Browsing `_satellite._udp` and `_nvstream._tcp` over Bonjour needs no entitlement, only the `NSLocalNetworkUsageDescription` and `NSBonjourServices` the Info.plist already carries. | Discovery is Bonjour only; the beacon fallback stays off and `docs/contract.md` says so. |
| Raw HID report access for the Direct path | Reading Switch Pro, N64 and generic HID pads by their reports, as dish-mac does with IOHIDManager and the desktops with their own readers. iOS has no public HID report API for an app: DriverKit with its USB transport entitlement exists on iPadOS only, and CoreHID is macOS only. | Every pad reaches the hot path through GameController alone; the Direct path and its USB output lane wait behind their own seam, and the entitlement request is made before that wave starts. |
| Background execution | Streaming while Dish is not frontmost. There is no entitlement for it that fits a controller bridge; the design keeps Dish open and dims instead. | Keep screen on and the dim cover; no `UIBackgroundModes`, no Live Activity. |

## 4. Decided differences

- **Appearance defaults to the system's, not dark.** The design handoff calls
  dark "the default" palette; the Settings › Appearance picker (System, Light,
  Dark) stores dish-mac's `ThemeMode` raw values under `theme_mode`, and a
  fresh install follows the system, as dish-mac does. The dark tokens are the
  design's; only the default differs.
- **iOS 26 only.** The design handoff describes an iOS 18 fallback for the tab
  bar and the accessory. This client has none: no `if #available`, no custom
  session bar.
- **One red for errors.** The design leaves a choice between `#FF6B5C` and
  `#E74C3C`; the code uses `#FF6B5C` in the dark palette
  (`DishTheme.error`).
- **iOS gives apps no pad speaker.** The Review step's Gets back column never
  carries a speaker.
- **A backgrounded Dish does not stream.** iOS suspends Dish when it leaves the
  foreground, so Keep screen on holds the idle timer off while a session is up
  and the dim exists to save power; nothing keeps the app running in the
  background, and no Live Activity is used (the design says so).
