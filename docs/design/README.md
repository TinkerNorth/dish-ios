# Dish for iOS: navigation and critical flows

Design handoff for building the Dish iOS app. This covers the navigation model, first-run setup and pairing, playing, and recovering from errors. The structure and behavior are decided. The visuals show direction; a full visual design comes later.

Source canvas (private, open it signed in): https://claude.ai/artifact/PBFKX2TTdJeNSvb2bUPkRf

## How to use this folder

1. Look at `screens/Main.png` (the app map), then the screens for the part you are building.
2. Read the sections below for how each screen maps to SwiftUI.
3. Open the matching file in `boards/` when you need exact copy, colors or sizes.

- `screens/`: a 2x PNG of every board. Phone screens are 402 × 874 pt (iPhone 16 Pro and 17 Pro size); play screens are landscape.
- `boards/`: one `.dc.html` per screen, plus `canvas.json`, which holds the board titles and the design notes. The boards are mockups drawn with absolutely positioned HTML. Do not port their layout code. Build with native SwiftUI components and use the boards only for content, copy and values. They open in a browser; the missing `support.js` does not matter.

Related repos (TinkerNorth on GitHub):
- `satellite`: the PC server and protocol.
- `dish-android`: the closest existing client. The setup flow and copy follow it.
- `dish-mac`: the pairing model. Its PIN paths run side by side, and Dish iOS copies that.

## Navigation model

There are three tabs, and each one has its own `NavigationStack`. The tab bar stays visible on pushed pages. Setup and play screens cover it.

```
TabView
├─ Controllers   NavigationStack
│   ├─ list of bound controllers → Controller page (push)
│   ├─ "Add a controller": its own button under the list, not a list row → setup cover, step 1
│   └─ toolbar: heart → Support Dish (tips)
├─ Connections   NavigationStack
│   ├─ Paired, Found on <Wi‑Fi name>, Moonlight hosts → PC detail (push)
│   ├─ toolbar: + → Add a PC by address
│   └─ Local Network denied → empty state with Open Settings
└─ Settings      NavigationStack
.tabViewBottomAccessory { SessionBar() }      // live link on every tab: PC, status, Dim, Play
.tabBarMinimizeBehavior(.onScrollDown)
```

Presentations:

| What | How |
|---|---|
| Setup (Welcome, then steps 1 to 3) | `.fullScreenCover`. Skip on every step goes to the Controllers tab. "Add a controller" opens it at step 1. |
| Pair with PIN | `.sheet`, from setup step 2 or from Pair on the Connections tab |
| Gamepad, Touchpad, Mouse | `.fullScreenCover`, locked to landscape. Exit is in the pause menu. |
| Pause menu | A native `Menu` on the pause button. Rumble is a `Toggle`, Emulate as is a `Picker`, Stop gamepad has `role: .destructive`. Motion is disabled with a reason when the emulated pad has no motion. |
| Low power dim | Full-screen black view; tap to wake |
| Forget PC | `.confirmationDialog` |
| PC problem | Shown once, in the session bar, with Reconnect. The Connections tab gets `.badge(1)`, and controller rows bound to that PC say "Connection lost". |

## Screen index

| Board | Screen | Presentation | Notes |
|---|---|---|---|
| `Main` | App map | n/a | Structure plus the iOS surfaces Dish hands off to |
| `A2-tabs` | Controllers tab, iOS 26+ | Tab root | Separate Add button, heart for tips, session accessory |
| `N1-tabs-ios18` | Controllers tab, iOS 18 | Tab root | Same code on iOS 18; see fallbacks |
| `N2-glass-scrolled` | Controller page scrolled, Clear glass | Push | Content under the glass bars |
| `N3-ios18-scrolled` | Controller page scrolled, iOS 18 | Push | Text back button, no subtitle |
| `N4-glass-minimized` | Scrolled further | Push | Tab bar minimized; accessory inline with a shorter line |
| `B1-welcome` | Welcome | Cover | Skip, Continue, Get Satellite link |
| `B2-input` | How do you want to play? (Input, 1 of 3) | Cover | A detected pad comes first, then Wired, Bluetooth, On-screen |
| `B3-local-network` | Local Network primer (Destination, 2 of 3) | Cover | Explains, then iOS asks. Shows the system alert. |
| `B4-pick-pc` | Pick your PC (Destination, 2 of 3) | Cover | Satellite PCs via Bonjour, Moonlight host, add by address |
| `B5-pair` | Pair sheet | Sheet | PIN entry and "Accept on your PC" run at once; Rename this iPhone |
| `B6-ready` | Review and bind (Binding, 3 of 3) | Cover | Emulate as, Motion, what carries each way; Bind goes to the Controllers tab |
| `C1-controller` | Controller page | Push | Status card, Binding, Functions, Telemetry |
| `C2-gamepad` | On-screen gamepad | Cover, landscape | Trigger rails, sticks, D-pad, face buttons, L3/R3, pause |
| `C3-pause` | Pause menu | Menu | See Presentations |
| `C4-mouse` | Mouse | Cover, landscape | Left, Scroll strip, Right, move pad |
| `C5-pocket` | Low power | Full screen | Streaming continues while dimmed |
| `D1-connections` | Connections tab | Tab root | Paired, Found, Moonlight hosts |
| `D2-pc-detail` | PC detail and Forget | Push and dialog | Latency, what it carries, Re-pair, Disconnect, Forget |
| `D3-no-network` | Local Network denied | Tab root | Empty state, Open Settings |
| `D4-host-lost` | PC stopped responding | Tab root | Error accessory with Reconnect, tab badge |
| `D5-settings` | Settings tab, light mode | Tab root | Device name, streaming, help, appearance, tips |

Not drawn yet:
- long-press menus on controller and PC rows
- swipe actions (Unbind, Forget)
- pull to refresh on Connections to rescan
- the "Add a PC by address" sheet
- the Touchpad screen
- the Setup guide, Help and Diagnostics pages
- iPad
- App Intents controls
- TipKit hints

## Native components and the iOS 18 fallback

Use standard components everywhere: `TabView`, `NavigationStack`, toolbar items, `List` in the inset grouped style, `Toggle`, `Menu`, `Picker`, sheets. On iOS 26 and later the system draws them in Liquid Glass. The glass follows each person's Clear or Tinted setting, so do not restyle the bars. Do not hard-code list corner radii either.

iOS 26+ only:
- `tabViewBottomAccessory`: read `@Environment(\.tabViewBottomAccessoryPlacement)`. When it is `.inline` (tabs minimized), show the short line, for example "3 pads · 4 ms" instead of "Streaming · 3 pads · 4 ms". See N4.
- `tabBarMinimizeBehavior(.onScrollDown)`
- `navigationSubtitle`: the controller page shows "84% battery · USB-C" under the title.

If the minimum is below iOS 26 (see N1 and N3):
- The session bar becomes a custom bar placed with `safeAreaInset(edge: .bottom)`, sitting on top of the tab bar.
- There is no navigation subtitle, so the battery moves into the status card.
- Set `.toolbarBackground(.visible, for: .tabBar)`. iOS 15 to 18 make the tab bar transparent when a list is short.

The minimum iOS version is still open. Setting it to iOS 26 removes both fallbacks.

## Platform requirements

- Local network:
  - `NSLocalNetworkUsageDescription`: "Dish finds Satellite on your Wi‑Fi and sends controller input straight to your PC."
  - `NSBonjourServices`: `_satellite._udp` and `_nvstream._tcp` (Moonlight hosts).
  - Ask only after the primer screen (B3). If it is denied, show D3, which deep-links to Settings › Dish.
- Raw UDP broadcast or multicast needs the `com.apple.developer.networking.multicast` entitlement, and Apple has to approve it. Bonjour browsing alone does not.
- GameController framework:
  - Pads: DualSense, DualShock 4, Xbox Wireless and Switch Pro, wired over USB-C or over Bluetooth.
  - Dish uses motion, the touchpad, rumble, adaptive triggers, the light bar, player LEDs and battery.
  - Apps cannot use the controller microphone or speaker. C1 says so.
- Dish cannot pair Bluetooth devices. Pads pair in Settings › Bluetooth, and the copy points there.
- iOS suspends Dish when it leaves the foreground, and streaming stops. While Dish is forwarding:
  - Set `isIdleTimerDisabled`.
  - Offer the dim screen (C5) and the "Dim screen after" setting.
  - Do not use Live Activities, because nothing keeps running in the background.
- `UIDevice.current.name` returns "iPhone", so the name Satellite sees is user-editable: "Rename this iPhone" in the pair sheet, and Settings › Name on your PC.
- Tips use StoreKit in-app purchases: the heart on the Controllers tab and Settings › Support Dish.
- Play screens:
  - landscape only
  - status bar hidden
  - `.persistentSystemOverlays(.hidden)`
  - `.defersSystemGestures(on: .all)`, so a swipe never exits mid-game

## Visual tokens (from the boards)

Dark is the default:

| Role | Value |
|---|---|
| Background | `#060818` |
| Grouped surface | `#0C1027` |
| Raised surface (sheets, menus) | `#131A3A` |
| Text | `#E6ECFF` |
| Secondary text | `#93A0C8` |
| Accent | `#4FE3FF` (pressed `#8FEFFF`) |
| Dish and Satellite glyphs | `#8FCFE3` |
| Online, on | `#22C55E` |
| Warning, unsteady | `#F59E0B` |
| Error, destructive | `#FF6B5C` (C1's Unbind uses `#E74C3C`; pick one) |
| Tips heart | `#FF6FB5` |

Light mode (D5) uses background `#F2F4F8`, surface `#FFFFFF`, text `#0C1430`, secondary `#5A6680` and accent `#0E7C97`. `#4FE3FF` fails contrast on white.

Type:
- SF Pro with Dynamic Type: 34 pt bold large titles, 17 pt body, 13 and 12 pt secondary.
- SF Mono for PC names in rows, IP addresses, latency and rates.
- Section headers are SF Mono uppercase, 12 pt semibold, tracking about 1.4.

Icons are inline SVG placeholders: a controller, the Satellite glyph and a gear. The app mark is version B, the dish tilted 28°. Use SF Symbols wherever one fits.

## Copy rules

- No emoji, no exclamation marks, no em dashes.
- Use these terms: Controllers, Connections, Settings, Bind, Unbind, Emulate as, Satellite, Moonlight host, Reconnect, Forget This PC.
- Setup steps read "Input · 1 of 3", "Destination · 2 of 3" and "Binding · 3 of 3".
- Telemetry numbers (1000 Hz, 250 Hz, ~120 Hz, 4 ms) are placeholders until measured on an iPhone.
- "Test buttons and sticks" and "Copy diagnostics" on the controller page are placeholders.
