// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

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
}
