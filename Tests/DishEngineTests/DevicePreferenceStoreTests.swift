// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

@MainActor
final class DevicePreferenceStoreTests: XCTestCase {

    func testAFreshInstallHasNoNameOfItsOwn() throws {
        XCTAssertEqual(try DevicePreferenceStore(defaults: TestDefaults.fresh(self)).state, "")
    }

    func testTheStoredNameIsRead() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set("Emir's iPhone", forKey: "device_name")
        XCTAssertEqual(DevicePreferenceStore(defaults: defaults).state, "Emir's iPhone")
    }

    func testANonTextStoredValueReadsAsNoName() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set(42, forKey: "device_name")
        XCTAssertEqual(DevicePreferenceStore(defaults: defaults).state, "42", "UserDefaults reads a number as its text")
        defaults.set(Data([0xFF]), forKey: "device_name")
        XCTAssertEqual(DevicePreferenceStore(defaults: defaults).state, "")
    }

    func testSettingTheNamePersistsAndPublishes() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = DevicePreferenceStore(defaults: defaults)
        store.setDeviceName("Den iPhone")
        XCTAssertEqual(store.state, "Den iPhone")
        XCTAssertEqual(DevicePreferenceStore(defaults: defaults).state, "Den iPhone", "a relaunch reads it back")
    }

    func testTheNameIsStoredWithoutSurroundingSpaces() throws {
        let store = try DevicePreferenceStore(defaults: TestDefaults.fresh(self))
        store.setDeviceName("  Den iPhone \n")
        XCTAssertEqual(store.state, "Den iPhone")
        store.setDeviceName("   ")
        XCTAssertEqual(store.state, "", "a blank name falls back to the system's")
    }

    func testSettingTheSameNameTwiceWritesOnce() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = DevicePreferenceStore(defaults: defaults)
        store.setDeviceName("Den iPhone")
        defaults.removeObject(forKey: DevicePreferenceStore.nameKey)
        store.setDeviceName("Den iPhone ")
        XCTAssertNil(defaults.string(forKey: DevicePreferenceStore.nameKey), "a repeat set is a no-op")
    }
}
