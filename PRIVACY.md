# Dish for iOS: Privacy Policy

**Effective date:** 2026-11-09.
**Canonical copy:** this file, at
[`https://github.com/TinkerNorth/dish-ios/blob/main/PRIVACY.md`](https://github.com/TinkerNorth/dish-ios/blob/main/PRIVACY.md).

This document describes what data the Dish iOS client collects, why, how long
it is retained, and the choices you have over it. The product as a whole spans
several repositories (`satellite`, `dish-android`, `dish-windows`,
`dish-linux`, `dish-mac`, `dish-ios`); this policy is specific to the iPhone
client. The server (`satellite`) runs on your own machine and has its own
policy. The other clients have their own policies and different behaviour, so
do not read one as describing another.

This policy describes the app as it is today: **wave 1, the shell.** The app
does not yet talk to a PC. Section 2.2 and section 4 say what the later waves
add, as plans, so that this file is true now and changes in the same commit
as the code that makes it untrue.

---

## 1. Short version

- Dish for iOS is meant to turn a game controller, or the iPhone's own screen,
  into a wireless gamepad for a `satellite` server on your own network. Today
  it does none of that: it is the app's shell, the setup walk and the
  Settings page. TinkerNorth does not operate a server for Dish at all.
- **In this version the app makes no network connection of any kind.** It has
  no account, no analytics SDK, no telemetry, no advertising identifier, no
  usage reporting and no crash reporting. It sends nothing to TinkerNorth or
  to anyone else.
- It stores four preferences and one flag on your iPhone, in the app's own
  preferences (`UserDefaults`), listed in section 2.1. Nothing is synced to a
  cloud account by the app.
- The app's Info.plist declares the Local Network permission and two Bonjour
  services, so the build is ready for the wave that finds your PC. Nothing in
  this version browses them or asks iOS for the permission; section 4 says
  what changes when something does.
- We do not sell, share, or rent your data. We do not show ads. We do not
  profile you.

---

## 2. What data is processed

### 2.1 Stays on your iPhone

Preferences are stored with `UserDefaults` in the app's preferences domain
(`com.tinkernorth.dish.ios` for the bundled app).

| Setting | Holds | Used for |
|---|---|---|
| `theme_mode` | `system`, `light` or `dark` (the fleet's key and values) | Drawing the app in the appearance you chose |
| `device_name` | The name you typed for "Name on your PC", trimmed; empty when you have not set one | The name the PC will list this iPhone by once the app can pair; iOS tells apps only "iPhone", so you name it |
| `keep_screen_on` | A switch, on by default | Holding the screen on while a session streams (there is no session yet) |
| `dim_after_seconds` | 10, 20, 30, 60, 120 or 0 for never; 20 by default | When the low-power dim rises while streaming |
| `onboarding_welcome_completed` | Whether the welcome was finished or skipped | Showing the setup cover on its own only once |

The setup walk keeps your answers in memory while it is open. Binding at its
last step records the request in memory and sends nothing; closing the app
forgets it. No file, database, keychain item or log is written by the app.

### 2.2 Sent to your own LAN, not to TinkerNorth

Nothing, in this version. The app opens no socket, browses no service and
sends no packet. The waves that follow are planned to add, as the other
clients do, and this section will list each of them before it ships:

- discovery: a Bonjour browse for `_satellite._udp` (and `_nvstream._tcp` for
  Moonlight hosts), which sends nothing of yours and reads the announcements
  of the PCs on your network;
- pairing and the control plane: HTTPS on port 9443 to the PC you chose;
- streaming: encrypted UDP on port 9876 to the PC you chose, carrying the
  controller's input, and bringing rumble and similar commands back.

### 2.3 Sent to TinkerNorth or a third party

Nothing. There is no TinkerNorth server for this app to talk to, no update
check (the App Store and TestFlight deliver updates) and no crash reporter.

The only way this app causes a request to a TinkerNorth or third-party address
is if you tap a link, which hands the URL to your default browser and is then
between you and that site. Today those links are the one that opens Satellite's
download page from the setup flow, and the one that opens Dish's page in the
Settings app.

---

## 3. Crash reports

None. This version carries no crash-reporting SDK, writes no crash log and
uploads nothing. iOS may collect crash reports itself, under the "Share with
App Developers" choice in Settings › Privacy & Security › Analytics &
Improvements; that is Apple's mechanism and policy, not the app's.

---

## 4. System capabilities the app uses

| Capability | Why |
|---|---|
| Local network access and Bonjour (`_satellite._udp`, `_nvstream._tcp`), declared in `App/Info.plist` with the usage text "Dish finds Satellite on your Wi‑Fi and sends controller input straight to your PC." | Declared for the discovery wave. Finding PCs on your Wi-Fi, and later talking to the one you chose, needs it; everything stays on your LAN. iOS asks once, at the first scan, after the setup flow's primer has explained why; if you refuse, the Connections page says so and points to Settings. This version never scans, so iOS never asks. |
| Keeping the screen on (the idle timer) | Held off only while a session is up and Keep screen on is set, so that iOS does not lock the screen and suspend Dish mid-game. There is no session in this version, so it is never held. |

The app asks for no other permission. It does not use the camera, the
microphone, location, contacts, photos, notifications or tracking. Later
waves add the GameController framework (reading controller input and writing
rumble back) and a keychain item per paired PC; each is listed here, with its
reason, in the same change that adds it.

---

## 5. Your choices

- **Change a preference** in Settings: the name, Keep screen on, Dim screen
  after, Appearance.
- **Turn the Local Network permission off** in Settings › Privacy & Security ›
  Local Network (or from Dish's page in Settings); the Connections page then
  says it cannot see your network.
- **Reset everything** by deleting the app. Its preferences go with it.

---

## 6. Children's privacy

Dish is a utility and is not directed at children. It collects no personal
information from anyone, and no account exists.

## 7. International transfers

None. This version sends no data anywhere.

## 8. Changes to this policy

Changes land in this file with a new effective date, in the same change as the
code that makes them necessary. The repository's history is the record.

## 9. Contact

Questions about this policy: open an issue in the repository, or email
`security@tinkernorth.com` for anything that should stay private.
