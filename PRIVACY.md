# Dish for iOS: Privacy Policy

**Effective date:** 2026-11-22.
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
same with a Moonlight host (Sunshine, Apollo or Wolf) on your network. It also
checks TinkerNorth's website for a newer list of the controllers it knows
(section 2.4), and it can hand a support report, your own words with a
diagnostics file, to your own mail app when you ask it to (section 2.5).
Section 2.2 says exactly what crosses your network; this file changes in the
same commit as the code that makes it untrue.

---

## 1. Short version

- Dish for iOS turns a game controller, or the iPhone's own screen, into a
  wireless gamepad for a `satellite` server on your own network. The one
  server TinkerNorth operates that the app contacts is the website,
  `dish.tinkernorth.com`, for the controller list (section 2.4).
- **Your controller input stays on your local network**, between this
  iPhone and the PC you paired, a Satellite or a Moonlight host (section 2.2).
  The app has no account, no analytics SDK, no telemetry, no advertising
  identifier, no usage reporting and no crash reporting. Three requests can
  leave your network, none of them carrying anything about you: the
  controller database check to `dish.tinkernorth.com`, which asks for a newer
  list of controllers, on by default and switched off in Settings (section
  2.4); Support Dish's question to the App Store, through StoreKit, for the
  price of its three tips, where a tip you choose is an App Store purchase
  (section 2.3); and a support report, your words with a diagnostics file,
  which only you send, from your own mail app (section 2.5).
- It stores its preferences, the PCs you paired and a device id on your
  iPhone (section 2.1), each PC's pairing key and the app's Moonlight
  identity in the Keychain, and each PC's certificate fingerprint in a file
  in the app's own container. Nothing is
  synced to a cloud account by the app.
- iOS asks for the Local Network permission the first time Dish looks for
  your PC, after the setup flow has explained why (section 4).
- Bluetooth is off for Dish until you turn on Settings › Steam Controllers ›
  Read over Bluetooth, which is when iOS asks. Dish then uses Bluetooth only
  to read the Steam Controllers you paired in Settings › Bluetooth, and only
  their input goes to your own PC (sections 2.2 and 4).
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
| `steam_bluetooth_enabled` | Settings › Steam Controllers › Read over Bluetooth: a switch, off by default | Whether Dish uses Bluetooth at all; while it is off the app makes no Bluetooth request and iOS never asks |
| `controller_db_check_enabled` | Settings › Controller database › Check for controller updates automatically: a switch, on by default (dish-mac's key) | Whether the app checks `dish.tinkernorth.com` for a newer controller list; while it is off the app sends that site nothing (section 2.4) |
| `controller_db_last_check_utc_ms`, `controller_db_last_check_result` | When the last controller database check ran and how it ended (`upToDate`, `updated`, `offline`, `invalid` or `off`) | Settings' and Diagnostics' line under the switch, and the diagnostics file |
| `controller_db_manifest_etag` | The `ETag` the website gave the last manifest it served | Sent back as `If-None-Match`, so an unchanged list costs one small answer; it names the file's version, not you |
| `touchpad_mode_preferences` | Each Steam Controller's trackpad pick (`stick`, `ds4` or `off`), once you chose one (dish-mac's key and words) | What a Steam Controller's trackpads are on the controller page; a Steam Controller is known by the identifier iOS gives this app for it |

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
| The controller database | `Application Support/Dish/controllers-v1/` in the app's container | The newest controller list the app downloaded, its strings in each language and the manifest that vouches for them; never written while the switch is off | Naming the Steam Controllers Dish reads over Bluetooth and the issues known for them; the copy built into the app is used until a newer one has been downloaded and checked |
| The Moonlight identity | The Keychain, labelled "Dish Moonlight client key" and "Dish Moonlight client certificate", readable after the first unlock and never moved to another device | An RSA key and the self-signed certificate around it, made once | Presented to every Moonlight host on every connection: it is how a host recognises the iPhone it paired with |

Forget This PC removes that PC's row, key, pin and last sighting, after
telling the PC to drop this iPhone. Forgetting a Moonlight host removes its
record, its bindings and its pin, after closing the app a live session of
yours started on it; the protocol has no way to unpair, so the host keeps its
own record of this iPhone until you remove it there. The setup walk keeps your answers in
memory while it is open. No database or log is written by the app, beside
the controller database it downloads (above), the diagnostics file it writes
when you tap Preview file or Continue in Mail on Report a problem (section 2.5), and TipKit's own store: Apple's TipKit framework keeps, in the app's container,
which of the app's four hints were shown, closed or no longer needed, so a
hint does not come back. It holds no name, address or controller.

Siri, Spotlight and the Shortcuts app can open the play screens, dim the
screen and connect to a paired PC through the app's App Intents. The app
donates nothing to them: it records no shortcut, activity or entity. When
you set up Connect to a PC in Shortcuts, the app answers with the names of
the PCs you paired, on the iPhone, so you can pick one; Apple's handling of
your shortcuts is under Apple's privacy policy.

While a controller is attached, the app reads the iPhone's battery level and
whether it is charging, every few seconds, through iOS's battery monitoring.
It stores none of it: the reading only decides which battery a PC is told
about, the controller's or this iPhone's, whichever is lower (section 2.2).

Settings › Setup & help › Diagnostics shows what the app sees right now
(each paired PC's session and its packet counters, each controller's rates
and binding, the Local Network status, the app and protocol versions) and a
log of this run of Dish: a PC's name and address, a controller's name, each
change of a link's state and each binding, at most 200 lines, kept in
memory only and gone when the app quits. It also shows which controller
database version is in force, where it came from and how the last check
ended, and, for a Steam Controller read over Bluetooth, its record in that
database. Copy puts that page's text on the pasteboard and Share hands it to
the share sheet, each only when you tap it; Report a problem and Ask a
question are described in section 2.5. The app sends none of it anywhere on its own.

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
  left them on, its battery level (or this iPhone's, when that is lower or
  the controller reports none), and a heartbeat every two seconds; the PC
  sends back the heartbeat's answer and the rumble, light-bar, trigger and
  player-light commands for the controller.
- **Forget This PC** sends that PC one request to drop this iPhone from its
  paired list.
- **A Steam Controller over Bluetooth** is a controller like any other: once
  bound, its buttons, sticks, triggers, extra buttons, motion and trackpads
  go to the PC it is bound to, as above, with this iPhone's battery level,
  since it reports none. Its Bluetooth traffic itself stays between the pad
  and this iPhone: Dish reads its input and writes it the settings that turn
  its keyboard-and-mouse mode off and on again, and the 2026 controller's
  rumble. Dish talks to no other Bluetooth device.
- **A support report** (section 2.5), only when you tap Preview file or
  Continue in Mail: one HTTPS request on port 9443 to each PC running
  Satellite 2.3.0 or later that has a session up with this iPhone, over the same pinned
  connection and pairing proof as the control plane, asking what that PC
  knows of this iPhone's connection (`/api/connections/{id}/diagnostics`).
  It carries nothing but the device id and the proof, and the app waits two
  seconds at most for the answer.
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
  left them on, its battery level (or this iPhone's, when that is lower or
  the controller reports none), and a keepalive every half second. The host
  sends back rumble, light-bar and motion requests for the controller.

### 2.3 Sent to TinkerNorth or a third party

Two things can reach TinkerNorth, both described below: the controller
database check, which asks TinkerNorth's website for a newer controller list
and carries nothing about you (section 2.4), and a support report, which
reaches us only if you send it from your own mail app (section 2.5). There is
no app update check (the App Store and TestFlight deliver updates) and no
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

### 2.4 Controller database updates

Dish ships with a list of the controllers it recognises: their USB and
Bluetooth ids, how each one talks, and the known issues a controller's page
and its Diagnostics card show. So that a newly supported controller does not
wait for an app release, the app checks for a newer list. About ten seconds
after launch, and then every six hours while it is in the foreground, it
fetches a small manifest from `https://dish.tinkernorth.com/controllers/v1/`
that names the newest version. Only when that version is newer than the one
the app has does it fetch the rest: the controller list and its text in each
language. These files are data, never code. The app checks each one's size
and SHA-256 checksum against the manifest before using it, and keeps the copy
it has when anything does not match.

`dish.tinkernorth.com` is an Amazon S3 bucket behind Amazon CloudFront,
operated for TinkerNorth by Amazon Web Services. The requests carry no
identifier, no cookie and no query, and use the system's default
`User-Agent`; the only header the app adds is `If-None-Match`, with the
`ETag` the site gave the last manifest. What the host's access logs can see is
what any web server sees: the IP address the request came from, and the
time. We use those logs as we use the rest of the website's: for capacity
planning and abuse detection only.

*Check for controller updates automatically* in Settings, on by default,
turns the check off. With it off, no request for the controller list leaves
your device, *Check now* is not offered, and the app keeps using the copy it
has. *Check now* runs one check when you tap it. The App Store and TestFlight
builds both make this check. Earlier versions of this policy said the app
talked to no TinkerNorth server at all; since 1.1.0 this check is the one
exception.

### 2.5 Reporting a problem

When something does not work, or you have a question, you can write to us from
Settings › Setup & help › Diagnostics › Report a problem (or Ask a question,
the same screen). Nothing happens unless you tap Preview file or Continue in
Mail there. You pick what the report is about, write what happened and what
you expected, and may pick the controller it concerns; the screen lists what
the file will hold before anything moves, and Preview file shows you the file
itself. The app then writes one file,
`dish-diagnostics-dish-ios-<date>-<time>.json`, in its temporary folder, and
Continue in Mail opens a new message in your own mail app addressed to
`support@tinkernorth.com`, with your words first in the body, then the
Diagnostics page's summary, and the file attached; where no mail account is set
up on this iPhone, it opens the share sheet with the file instead. Nothing is
sent until you press Send, and you can read the file or remove it first. The
message then travels like any email you send, through your own mail provider.

To make the file, the app asks each PC running Satellite 2.3.0 or later that
has a session up with this iPhone what it knows of that connection (section
2.2). The PC answers with its own scrubbed account of this iPhone's
connection: its Satellite version and platform, its controller drivers and
their versions, the virtual controllers this iPhone's pads became with what
went in and came out of them, the audio it granted, its counters and its log
lines for this connection, with no machine name, no other device's name or
address, and no secret. A PC that cannot answer in two seconds, or runs an
older Satellite, is represented by what the app already fetched from it (its
version, protocol, drivers and audio grant). A Moonlight host is not asked
anything; the file holds the version it already gave, never its name.
Whatever a PC answered, the app replaces that PC's name and address with its
alias everywhere in the answer before it enters the file.

The file holds:

- Your own words, the category you picked, and the controller you picked, by
  its record id or its name.
- The app's version and build.
- Your device's model identifier (such as `iPhone18,1`) and iOS version, its
  battery level and whether it is charging, its temperature as iOS rates it
  (nominal to critical), and whether Low Power Mode is on. iOS gives an app no
  Wi-Fi signal reading, so the file has none.
- Which controller database version the app uses, where it came from, and
  when the last check ran and how it ended.
- For each controller, the on-screen one included: its record in the
  controller database where Dish reads the controller's ids itself (the Steam
  Controllers over Bluetooth), its verification, how it is connected and how
  Dish reads it, its name, the product category GameController gives it, how
  many input frames it published and at what rate with the last one (the
  buttons held and where the sticks and triggers stood), and how many
  rumble, light-bar, player-light and trigger commands reached it with the
  last of each.
- For each controller you tested under Diagnostics › Controller tests, the
  tests you answered "Did it work?" for (the newest twenty of this run): each
  test's name, your answer, and when the test ended. The tests themselves
  only drive the controller from this device; nothing about them leaves it
  unless you send a report.
- The PCs you use, as "Host 1", "Host 2", with their kind (Satellite or
  Moonlight), version, protocol and link state, the session as this iPhone
  sees it (each controller slot and what the PC answered for it, the last
  heartbeat answer, the round-trip times, and counts of each kind of message
  sent and received), and what the PC said of the connection, as above. Never
  their names or addresses.
- The Diagnostics page's log of this run, with every PC named by its alias.

It **never** holds pairing keys or secrets, certificate fingerprints, IP
addresses, Wi-Fi names, the names of your paired PCs or devices, the device
id or the Moonlight id, or anything from a microphone or a speaker. We use
what you send only to look into the problem you wrote to us about.

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
| Battery monitoring (`UIDevice`) | The iPhone's battery level and charging state, read while a controller is attached so a PC is told the lower of it and the controller's, and when a support report is made, for its file (section 2.5); no permission is asked and nothing is stored (section 2.1). |
| The network, beyond your LAN | One HTTPS request to `dish.tinkernorth.com` ten seconds after launch and every six hours while Dish is in the foreground, and when you tap Check now, unless the switch is off (section 2.4). No permission is asked. |
| The mail compose sheet (MessageUI) | Opened only when you tap Continue in Mail on Report a problem, addressed to support with your words and the diagnostics file; the app cannot send it, only you can (section 2.5). No permission is asked. |
| The thermal state and Low Power Mode (`ProcessInfo`) | Read only when a support report is made, for its file (section 2.5); no permission is asked and nothing is stored. |
| Bluetooth (Core Bluetooth), declared in `App/Info.plist` with the usage text "Dish reads the Steam Controllers you pair and sends their input straight to your PC." | Reading the Steam Controllers you paired in Settings › Bluetooth, which iOS keeps from games. Off until you turn on Settings › Steam Controllers › Read over Bluetooth, which is when iOS asks; the app neither scans for nor pairs with anything, and looks only among the devices iOS has already connected. If you refuse, the row says so and points to Settings. |

The app asks for no other permission. It does not use the camera, the
microphone, location, contacts, photos, notifications or tracking. It reads
your controllers through the GameController framework, which needs no
permission, and writes rumble and light commands back to them; a Steam
Controller it reads over Bluetooth once you opt in.

---

## 5. Your choices

- **Change a preference** in Settings: the name, Keep screen on, Dim screen
  after, Appearance.
- **Stop the controller database check** by turning Check for controller
  updates automatically off in Settings › Controller database; the app then
  sends `dish.tinkernorth.com` nothing and keeps the copy it has.
- **Turn the Local Network permission off** in Settings › Privacy & Security ›
  Local Network (or from Dish's page in Settings); the Connections page then
  says it cannot see your network.
- **Stop using Bluetooth** by turning Read over Bluetooth off in Settings ›
  Steam Controllers, which hands each Steam Controller its keyboard-and-mouse
  mode back, or by turning the Bluetooth permission off in Settings › Privacy
  & Security › Bluetooth.
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

Your controller input never leaves your local network. The controller
database check is answered by Amazon CloudFront, which may serve it from any
country where it operates, including the United States; it carries nothing
about you, and the host sees the IP address and the time (section 2.4). A
diagnostics email you send travels through your own mail provider, under its
terms (section 2.5).

## 8. Changes to this policy

Changes land in this file with a new effective date, in the same change as the
code that makes them necessary. The repository's history is the record.

## 9. Contact

Questions about this policy: open an issue in the repository, or email
`security@tinkernorth.com` for anything that should stay private.
