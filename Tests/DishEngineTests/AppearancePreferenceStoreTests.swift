// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

@MainActor
final class AppearancePreferenceStoreTests: XCTestCase {

    func testAFreshInstallFollowsTheSystem() throws {
        XCTAssertEqual(try AppearancePreferenceStore(defaults: TestDefaults.fresh(self)).state, .system)
    }

    func testTheStoredModeIsReadUnderTheFleetsKeyWithDishMacsValues() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set("dark", forKey: "theme_mode")
        XCTAssertEqual(AppearancePreferenceStore(defaults: defaults).state, .dark)
        defaults.set("light", forKey: "theme_mode")
        XCTAssertEqual(AppearancePreferenceStore(defaults: defaults).state, .light)
    }

    func testAnUnknownStoredModeReadsAsTheSystem() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set("sepia", forKey: "theme_mode")
        XCTAssertEqual(AppearancePreferenceStore(defaults: defaults).state, .system)
    }

    func testSettingTheModePersistsAndPublishes() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = AppearancePreferenceStore(defaults: defaults)
        store.setAppearance(.light)
        XCTAssertEqual(store.state, .light)
        XCTAssertEqual(defaults.string(forKey: AppearancePreferenceStore.modeKey), "light")
        XCTAssertEqual(AppearancePreferenceStore(defaults: defaults).state, .light, "a relaunch reads it back")
    }

    func testSettingTheSameModeTwiceWritesOnce() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = AppearancePreferenceStore(defaults: defaults)
        store.setAppearance(.dark)
        defaults.removeObject(forKey: AppearancePreferenceStore.modeKey)
        store.setAppearance(.dark)
        XCTAssertNil(defaults.string(forKey: AppearancePreferenceStore.modeKey), "a repeat set is a no-op")
    }
}
