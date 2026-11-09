// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import XCTest
@testable import Dish

/// Settings › Name on your PC.
final class DeviceNameMappersTests: XCTestCase {

    func testWithNoNameTheDraftStartsEmptyUnderTheSystemsName() {
        XCTAssertEqual(deviceNamePageState(preferences: FactsFixture.preferences), DeviceNamePageState(
            title: "Name on your PC",
            placeholder: "iPhone",
            draft: "",
            footer: "Your PC shows this name when Dish connects to it."
        ))
    }

    func testTheDraftStartsAtTheStoredName() {
        let named = PreferencesFacts(deviceName: "Den iPhone", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system)
        XCTAssertEqual(deviceNamePageState(preferences: named).draft, "Den iPhone")
    }
}
