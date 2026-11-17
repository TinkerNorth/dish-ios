// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import XCTest
@testable import Dish

/// The Settings tab (D5).
final class SettingsMappersTests: XCTestCase {

    private func page(_ preferences: PreferencesFacts = FactsFixture.preferences) -> SettingsPageState {
        settingsPageState(preferences: preferences, appVersion: "0.1.0")
    }

    func testWithNoNameOfItsOwnThisIPhoneIsCalledIPhone() {
        let device = page().device
        XCTAssertEqual(device, DeviceSectionState(
            title: "This iPhone",
            nameTitle: "Name on your PC",
            name: "iPhone",
            footer: "iOS only tells apps “iPhone”. Name it so Satellite can tell your devices apart."
        ))
    }

    func testAStoredNameIsShown() {
        let named = PreferencesFacts(deviceName: "Den iPhone", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system)
        XCTAssertEqual(page(named).device.name, "Den iPhone")
    }

    func testWhileStreamingShowsTheSwitchTheDelayAndEveryOption() {
        let streaming = page().streaming
        XCTAssertEqual(streaming.title, "While streaming")
        XCTAssertEqual(streaming.keepScreenOnTitle, "Keep screen on")
        XCTAssertTrue(streaming.keepScreenOn)
        XCTAssertEqual(streaming.dimTitle, "Dim screen after")
        XCTAssertEqual(streaming.dimAfter, .twentySeconds)
        XCTAssertEqual(streaming.options.map(\.delay), DimDelay.allCases)
        XCTAssertEqual(streaming.options.map(\.title), ["10 s", "20 s", "30 s", "1 min", "2 min", "Never"])
        XCTAssertEqual(streaming.footer, "iOS pauses apps you leave, so Dish stays open and dims itself instead of locking.")
    }

    func testTheStoredStreamingChoicesAreSelected() {
        let chosen = PreferencesFacts(deviceName: "", keepScreenOn: false, dimAfter: .never, appearance: .system)
        XCTAssertFalse(page(chosen).streaming.keepScreenOn)
        XCTAssertEqual(page(chosen).streaming.dimAfter, .never)
    }

    func testSetupAndHelpOffersTheGuideHelpAndDiagnostics() {
        XCTAssertEqual(page().help, SetupHelpSectionState(
            title: "Setup & help",
            guide: "Setup guide",
            guideSymbol: "sparkles",
            help: "Help & FAQ",
            helpSymbol: "questionmark.circle",
            diagnostics: "Diagnostics",
            diagnosticsSymbol: DishSymbol.diagnostics
        ))
        XCTAssertEqual(DishSymbol.diagnostics, "waveform.path.ecg")
    }

    func testAppearanceOffersSystemLightAndDarkWithTheStoredOneSelected() {
        let dark = PreferencesFacts(deviceName: "", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .dark)
        let appearance = page(dark).appearance
        XCTAssertEqual(appearance.title, "Appearance")
        XCTAssertEqual(appearance.selected, .dark)
        XCTAssertEqual(appearance.options.map(\.appearance), [.system, .light, .dark])
        XCTAssertEqual(appearance.options.map(\.title), ["System", "Light", "Dark"])
    }

    func testAboutOffersTipsTheVersionTheLinksAndTheLicenses() {
        XCTAssertEqual(page().about, AboutSectionState(
            title: "About",
            support: "Support Dish",
            supportValue: "Tips",
            supportSymbol: "heart.fill",
            versionTitle: "Version",
            version: "0.1.0",
            links: [
                PageLink(title: "Website", url: DishLinks.website),
                PageLink(title: "Source code", url: DishLinks.source),
                PageLink(title: "Privacy policy", url: DishLinks.privacy)
            ],
            licenses: "Open source licenses"
        ))
    }

    func testForwardedFeaturesOfferTheThreeSwitchesAndTheLightBarWithTheirDetails() {
        let features = page().features
        XCTAssertEqual(features.title, "Forwarded features")
        XCTAssertEqual(features.rows.map(\.feature), [.motion, .rumble, .touchpad])
        XCTAssertEqual(features.rows.map(\.title), ["Motion", "Rumble", "Touchpad"])
        XCTAssertEqual(features.rows.map(\.detail), [
            "Forward gyroscope and accelerometer to the host, used for motion aiming in games that support it.",
            "Play vibration the host game sends back on your controller.",
            "Forward the DualSense / DualShock 4 touchpad. Controllers without a touchpad ignore this."
        ])
        XCTAssertEqual(features.rows.map(\.isOn), [true, true, true], "a fresh install has everything on")
        XCTAssertEqual(features.lightBarTitle, "Light bar")
        XCTAssertEqual(features.lightBarDetail, "Follow game: the controller LED matches the host game. Off: leave the LED untouched.")
        XCTAssertEqual(features.lightBarOptions.map(\.mode), [.followGame, .off])
        XCTAssertEqual(features.lightBarOptions.map(\.title), ["Follow game", "Off"])
        XCTAssertEqual(
            features.footer,
            "Features only apply when your controller's hardware supports them. The controller list shows what was detected."
        )
    }

    // MARK: - Steam Controllers

    private func steam(_ status: SteamBluetoothStatus) -> SteamControllersSectionState {
        settingsPageState(preferences: FactsFixture.preferences, steamBluetooth: status, appVersion: "0.1.0").steamControllers
    }

    func testSteamControllersOverBluetoothStandOffUntilThePersonOptsIn() {
        XCTAssertEqual(page().steamControllers, SteamControllersSectionState(
            title: "Steam Controllers",
            toggleTitle: "Read over Bluetooth",
            isOn: false,
            line: SteamBluetoothLine(text: "Dish doesn’t use Bluetooth until you turn this on.", warns: false),
            footer: "iOS doesn’t offer Steam Controllers to games, so Dish reads them over Bluetooth itself."
                + " Turning this on asks for Bluetooth."
        ))
    }

    func testEachStateOfBluetoothShowsItsOwnLineOnTheRow() {
        let lines: [(SteamBluetoothStatus, String, Bool)] = [
            (.waiting, "Waiting for Bluetooth.", false),
            (.on, "Reading the Steam Controllers paired in Settings › Bluetooth.", false),
            (.bluetoothOff, "Bluetooth is turned off.", true),
            (.refused, "Dish isn’t allowed to use Bluetooth. Allow it in Settings › Privacy & Security › Bluetooth.", true),
            (.restricted, "Bluetooth is restricted on this device.", true),
            (.unsupported, "This device has no Bluetooth LE.", true)
        ]
        for (status, text, warns) in lines {
            let section = steam(status)
            XCTAssertTrue(section.isOn, "\(status): the switch is on")
            XCTAssertEqual(section.line, SteamBluetoothLine(text: text, warns: warns), "\(status)")
        }
        XCTAssertEqual(Set(lines.map(\.1)).count, lines.count, "no two states share a line")
    }

    func testOnlyWhatThePersonCanChangeWarns() {
        XCTAssertEqual(steam(.refused).line.color, DishTheme.warning)
        XCTAssertEqual(steam(.on).line.color, DishTheme.muted)
    }

    func testTheForwardedFeaturesShowTheGlobalSwitchesAsTheyStand() {
        let flags = ForwardingFlags(motion: false, touchpad: true, rumble: false, lightbar: false)
        let features = settingsPageState(preferences: FactsFixture.preferences, forwarding: flags, appVersion: "0.1.0").features
        XCTAssertEqual(features.rows.map(\.isOn), [false, false, true])
        XCTAssertEqual(features.lightBar, .off)
    }
}
