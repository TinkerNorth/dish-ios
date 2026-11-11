// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// Every preference intent lands in the facts the shell draws.
@MainActor
final class AppModelPreferencesTests: XCTestCase {

    /// No pads: the simulator vends any controller plugged into the Mac it
    /// runs on, once GameController has looked, which an empty source holds
    /// out of the facts.
    private func model() throws -> AppModel {
        try AppModel(defaults: TestDefaults.fresh(self), controllerSource: FakeControllerSource())
    }

    func testAFreshModelPublishesRealEmptyFactsAndTheDefaults() throws {
        let facts = try model().shellFacts
        XCTAssertEqual(facts.controllers, [])
        XCTAssertEqual(facts.paired, [])
        XCTAssertEqual(facts.found, [])
        XCTAssertFalse(facts.scanning)
        XCTAssertNil(facts.session)
        XCTAssertEqual(facts.localNetwork, .unknown)
        XCTAssertEqual(
            facts.preferences,
            PreferencesFacts(deviceName: "", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system)
        )
    }

    func testSettingTheDeviceNameChangesTheFacts() throws {
        let model = try model()
        model.setDeviceName("Den iPhone")
        XCTAssertEqual(model.shellFacts.preferences.deviceName, "Den iPhone")
    }

    /// iOS tells an app only the model's own name, so an unnamed device is
    /// the iPhone or the iPad the scene says it runs on.
    func testAnUnnamedDeviceIntroducesItselfAsTheDeviceTheSceneSaysItIs() {
        XCTAssertEqual(wireDeviceName("", on: .phone), "iPhone")
        XCTAssertEqual(wireDeviceName("", on: .pad), "iPad")
        XCTAssertEqual(wireDeviceName("Den iPad", on: .pad), "Den iPad", "the person's own name wins")
    }

    func testTheModelNamesTheSatelliteTheDeviceItWasBuiltFor() throws {
        let defaults = try TestDefaults.fresh(self)
        let pad = AppModel(defaults: defaults, deviceKind: .pad)
        XCTAssertEqual(pad.network.wifi.deviceName(), "iPad")
        pad.setDeviceName("Den iPad")
        XCTAssertEqual(pad.network.wifi.deviceName(), "Den iPad")
        let phone = try AppModel(defaults: TestDefaults.fresh(self))
        XCTAssertEqual(phone.network.wifi.deviceName(), "iPhone", "an iPhone is the default")
    }

    func testTurningKeepScreenOnOffChangesTheFacts() throws {
        let model = try model()
        model.setKeepScreenOn(false)
        XCTAssertFalse(model.shellFacts.preferences.keepScreenOn)
    }

    func testChoosingADimDelayChangesTheFacts() throws {
        let model = try model()
        model.setDimAfter(.never)
        XCTAssertEqual(model.shellFacts.preferences.dimAfter, .never)
    }

    func testChoosingAnAppearanceChangesTheFacts() throws {
        let model = try model()
        model.setAppearance(.dark)
        XCTAssertEqual(model.shellFacts.preferences.appearance, .dark)
    }

    func testTheModelSharesItsDefaultsWithTheOnboardingStore() throws {
        let defaults = try TestDefaults.fresh(self)
        AppModel(defaults: defaults).onboarding.markWelcomeComplete()
        XCTAssertTrue(OnboardingPreferenceStore(defaults: defaults).state.welcomeCompleted)
    }
}
