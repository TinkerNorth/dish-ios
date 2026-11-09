// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// Every preference intent lands in the facts the shell draws.
@MainActor
final class AppModelPreferencesTests: XCTestCase {

    private func model() throws -> AppModel {
        try AppModel(defaults: TestDefaults.fresh(self))
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
