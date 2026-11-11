# Dish for iOS: Privacy Policy

**Effective date:** 2026-11-10.
**Canonical copy:** this file, at
[`https://github.com/TinkerNorth/dish-ios/blob/main/PRIVACY.md`](https://github.com/TinkerNorth/dish-ios/blob/main/PRIVACY.md).

This document describes what data the Dish iOS client collects, why, how long
it is retained, and the choices you have over it. The product as a whole spans
several repositories (`satellite`, `dish-android`, `dish-windows`,
`dish-linux`, `dish-mac`, `dish-ios`); this policy is specific to the iPhone
client. The server (`satellite`) runs on your own machine and has its own
policy. The other clients have their own policies and different behaviour, so
do not read one as describing another.

This policy describes the app as it is today: it finds a Satellite on your
Wi-Fi, pairs with it and streams a controller's input to it, and it does the
same with a Moonlight host (Sunshine, Apollo or Wolf) on your network.
Section 2.2 says exactly what crosses your network; this file changes in the
same commit as the code that makes it untrue.

---

## 1. Short version

- Dish for iOS turns a game controller, or the iPhone's own screen, into a
  wireless gamepad for a `satellite` server on your own network. TinkerNorth
  does not operate a server for Dish at all.
- **Everything the app sends stays on your local network**, between this
  iPhone and the PC you paired, a Satellite or a Moonlight host (section 2.2). It has no account, no analytics
  SDK, no telemetry, no advertising identifier, no usage reporting and no
  crash reporting. It sends nothing to TinkerNorth or to anyone else. The one
  exception is Apple's: Support Dish asks the App Store, through StoreKit, for
  the price of its three tips, and a tip you choose is an App Store purchase
  (section 2.3).
- It stores its preferences, the PCs you paired and a device id on your
  iPhone (section 2.1), each PC's pairing key and the app's Moonlight
  identity in the Keychain, and each PC's certificate fingerprint in a file
  in the app's own container. Nothing is
  synced to a cloud account by the app.
- iOS asks for the Local Network permission the first time Dish looks for
  your PC, after the setup flow has explained why (section 4).
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
| `local_network_primed` | Whether the setup walk has explained the Local Network question (dish-mac's key) | Keeping the Connections tab from looking for PCs as it opens, which is what makes iOS ask, until that explanation was seen; your own scan counts as the question asked |
| `feature_motion_enabled`, `feature_rumble_enabled`, `feature_touchpad_enabled`, `feature_lightbar_mode` | Settings › Forwarded features: three switches, on by default, and `followGame` or `off` (the desktops' keys) | Whether Dish sends motion and the touchpad to the PC and acts on rumble and the light bar, above each controller's own switches |
| `deadzone:<controller id>` | A controller's stick and trigger dead zones as `{"s":…,"t":…}`, once you changed them (the desktops' shape) | The controller page's Dead zones; Reset to defaults erases it |

Beside them, for the PCs you pair:

| Stored | Where | Holds | Used for |
|---|---|---|---|
| `deviceId` | `UserDefaults` | A random id made on first use, not derived from the device | The id the PC knows this iPhone by; it rides every request to the PC you paired, and it is not a secret |
| `wifi_list` | `UserDefaults` | Each paired PC's name, its address and ports, and its machine id | Reconnecting to the PCs you paired, and finding one that moved address |
| `wifi_binding_list` | `UserDefaults` | Which controller is bound to which paired PC | Binding a controller to its PC again when it returns after the app was closed; Unbind and Forget This PC erase it |
| `wifi_last_seen:<PC>` | `UserDefaults` | When a session with that PC last ended | The "seen yesterday" line of an offline PC |
| The pairing key | The Keychain, readable after the first unlock and never moved to another device (`com.tinkernorth.dish.ios.pairing-key`) | One 32-byte key per paired PC, which the PC handed over when you paired | Proving to that PC that this iPhone is the one you paired; the traffic itself is encrypted under a fresh key per session derived from it |
| The certificate pins | `Application Support/Dish/cert-pins.json` in the app's container | Each PC's address and the SHA-256 fingerprint of the certificate it showed the first time; a Moonlight host's under `moonlight:<address>`, replaced by the one a pairing proves | Refusing a later certificate that differs, so nothing else on your network can pretend to be your PC (trust on first use) |
| `moonlight_host_list` | `UserDefaults` | Each Moonlight host you added or paired with: its name, address, HTTP and HTTPS ports, the id it answers with, the app and the controller type picked for it, and whether it accepted this iPhone | Pairing with and starting sessions on those hosts |
| `moonlight_binding_list` | `UserDefaults` | Which controller is bound to which Moonlight host, and the type it is plugged in as | Forgetting a host's bindings with it |
| `moonlight_uniqueid` | `UserDefaults` | A random sixteen-character id made on first use, not derived from the device | The name a Moonlight host files this iPhone under |
| The Moonlight identity | The Keychain, labelled "Dish Moonlight client key" and "Dish Moonlight client certificate", readable after the first unlock and never moved to another device | An RSA key and the self-signed certificate around it, made once | Presented to every Moonlight host on every connection: it is how a host recognises the iPhone it paired with |

Forget This PC removes that PC's row, key, pin and last sighting, after
telling the PC to drop this iPhone. Forgetting a Moonlight host removes its
record, its bindings and its pin, after closing the app a live session of
yours started on it; the protocol has no way to unpair, so the host keeps its
own record of this iPhone until you remove it there. The setup walk keeps your answers in
memory while it is open. No database or log is written by the app.
telling the PC to drop this iPhone. The setup walk keeps your answers in
memory while it is open. No database or log is written by the app, beside
TipKit's own store: Apple's TipKit framework keeps, in the app's container,
which of the app's four hints were shown, closed or no longer needed, so a
hint does not come back. It holds no name, address or controller.

Siri, Spotlight and the Shortcuts app can open the play screens, dim the
screen and connect to a paired PC through the app's App Intents. The app
donates nothing to them: it records no shortcut, activity or entity. When
you set up Connect to a PC in Shortcuts, the app answers with the names of
the PCs you paired, on the iPhone, so you can pick one; Apple's handling of
your shortcuts is under Apple's privacy policy.

Settings › Setup & help › Diagnostics shows what the app sees right now
(each paired PC's session and its packet counters, each controller's rates
and binding, the Local Network status, the app and protocol versions) and a
log of this run of Dish: a PC's name and address, a controller's name, each
change of a link's state and each binding, at most 200 lines, kept in
memory only and gone when the app quits. Copy puts that page's text on the
pasteboard and Share hands it to the share sheet, each only when you tap
it; the app sends it nowhere on its own.

### 2.2 Sent to your own LAN, not to TinkerNorth

Everything below goes only to the PC you chose, on your local network, and
nothing of it leaves that network:

- **Discovery**: a Bonjour browse for `_satellite._udp`, which sends nothing
  of yours and reads the announcements of the PCs on your network (their
  name, address, ports and machine id).
- **Pairing and the control plane**: HTTPS on port 9443 to the PC you chose,
  carrying the device id, the name you gave this iPhone (or "iPhone"), the
  PIN of the pairing, a proof of the pairing key (never the key itself, except
  that the PC hands the key to this iPhone once when you pair), and a
  description of each controller you bound (the kind it is emulated as and
  the features you left on). The PC's certificate is self-signed, so the app
  pins it on first contact instead of trusting a certificate authority.
- **Streaming**: UDP on port 9876 to the PC you chose, encrypted with
  ChaCha20-Poly1305 under a key fresh for each session: each bound
  controller's buttons, sticks and triggers, its motion and touchpad when you
  left them on, its battery level, and a heartbeat every two seconds; the PC
  sends back the heartbeat's answer and the rumble, light-bar, trigger and
  player-light commands for the controller.
- **Forget This PC** sends that PC one request to drop this iPhone from its
  paired list.
- **Moonlight discovery**: a Bonjour browse for `_nvstream._tcp` when the
  Moonlight hosts page opens and when you tap Scan there, which sends nothing
  of yours and reads the hosts' announcements.
- **Moonlight probes and pairing**: HTTP on port 47989 to the host you chose
  or typed, asking what it is (`/serverinfo`) and pairing with it, carrying
  your `moonlight_uniqueid`, the device name the protocol fixes (`roth`), the
  app's certificate, and a salt and challenges derived from the PIN the app
  showed you; the PIN itself never crosses the wire. The last pairing step and
  everything after it use HTTPS on port 47984 with mutual TLS, presenting the
  app's certificate.
- **Moonlight sessions**: over that HTTPS, the app to start or close and a key
  made for the session; RTSP on the port the host names (48010 by default);
  UDP pings to the host's video and audio ports, which keep them open (no video
  or audio is asked for); and the control stream, UDP to the host's control
  port encrypted with that session's key: each bound controller's type and
  features, its buttons, sticks and triggers, its motion and touchpad when you
  left them on, its battery level, and a keepalive every half second. The host
  sends back rumble, light-bar and motion requests for the controller.

### 2.3 Sent to TinkerNorth or a third party

Nothing reaches TinkerNorth. There is no TinkerNorth server for this app to
talk to, no update check (the App Store and TestFlight deliver updates) and no
crash reporter.

Support Dish sells three optional tips as consumable in-app purchases. When
its page opens, StoreKit asks the App Store for their prices; when you buy a
tip, the purchase and its payment happen between you and Apple, under Apple's
privacy policy. Dish never sees your card or your Apple Account; it receives
only StoreKit's signed record that the tip completed, which it marks finished
and does not store. A tip unlocks nothing.

The only way this app causes a request to a TinkerNorth or third-party address
is if you tap a link, which hands the URL to your default browser and is then
between you and that site. Today those links are Satellite's download page
from the setup flow, Sunshine's project page from the Moonlight hosts page,
Dish's page in the Settings app, and Settings › About's and Help & FAQ's links
to the website, the source code and this policy.

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
| Local network access and Bonjour (`_satellite._udp`, `_nvstream._tcp`), declared in `App/Info.plist` with the usage text "Dish finds Satellite on your Wi‑Fi and sends controller input straight to your PC." | Finding PCs on your Wi-Fi and talking to the one you chose; everything stays on your LAN. iOS asks once, at the first scan, which the setup flow's primer runs after it has explained why; if you refuse, the Connections page says so and points to Settings. The Moonlight service is browsed when the Moonlight hosts page opens. |
| The Keychain | One item per paired PC, holding its pairing key, and the Moonlight identity, a key and its certificate (section 2.1). |
| Keeping the screen on (the idle timer) | Held off only while a session is up and Keep screen on is set, so that iOS does not lock the screen and suspend Dish mid-game. There is no session in this version, so it is never held. |
| App Intents (Siri, Spotlight, the Shortcuts app) | Five actions (open the gamepad, the touchpad or the mouse, dim the screen, connect to a paired PC) that open the app; no permission is asked and nothing is donated (section 2.1). |
| TipKit | Four hints about the app's own controls, remembered on the iPhone (section 2.1). |

The app asks for no other permission. It does not use the camera, the
microphone, location, contacts, photos, notifications or tracking. It reads
your controllers through the GameController framework, which needs no
permission, and writes rumble and light commands back to them.

---

## 5. Your choices

- **Change a preference** in Settings: the name, Keep screen on, Dim screen
  after, Appearance.
- **Turn the Local Network permission off** in Settings › Privacy & Security ›
  Local Network (or from Dish's page in Settings); the Connections page then
  says it cannot see your network.
- **Forget a PC** to remove its row, its pairing key and its pin, after the
  app tells the PC to drop this iPhone; a Moonlight host's record, bindings
  and pin go the same way.
- **Reset everything** by deleting the app. Its preferences and files go
  with it; iOS keeps an app's Keychain items after the app is deleted, so
  Forget each PC first to remove its pairing key too. The Moonlight identity
  is not removed by a Forget: it stays in the Keychain, and a Moonlight host
  you paired keeps recognising this iPhone until you remove it there.

---

## 6. Children's privacy

Dish is a utility and is not directed at children. It collects no personal
information from anyone, and no account exists.

## 7. International transfers

None. Nothing the app sends leaves your local network.

## 8. Changes to this policy

Changes land in this file with a new effective date, in the same change as the
code that makes them necessary. The repository's history is the record.

## 9. Contact

Questions about this policy: open an issue in the repository, or email
`security@tinkernorth.com` for anything that should stay private.
