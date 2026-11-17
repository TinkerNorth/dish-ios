// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import UIKit
import XCTest
@testable import Dish

/// The device's own battery as the scene hands it to the engine: UIKit's
/// level and charge state as a reading.
@MainActor
final class DeviceBatteryTests: XCTestCase {

    func testTheDevicesLevelIsAPercentAndUnpluggedIsDischarging() {
        XCTAssertEqual(deviceBatteryReading(level: 0.42, state: .unplugged), BatteryReading(level: 42, state: .discharging))
        XCTAssertEqual(deviceBatteryReading(level: 0.8, state: .charging), BatteryReading(level: 80, state: .charging))
        XCTAssertEqual(deviceBatteryReading(level: 1, state: .full), BatteryReading(level: 100, state: .full))
    }

    func testADeviceThatKnowsNeitherItsLevelNorItsStateReportsNoBattery() {
        XCTAssertNil(deviceBatteryReading(level: -1, state: .unknown), "monitoring off, or a simulator")
    }

    /// The simulator supports no battery monitoring (probed: the switch reads
    /// back off, the level is -1 and the state unknown), so there the device
    /// reports no battery and a pad sends its own; the switch is a device's
    /// to show.
    func testTheSystemBatteryIsUIKitsLevelAndStateMapped() {
        let battery = SystemDeviceBattery()
        XCTAssertEqual(battery.reading, deviceBatteryReading(level: UIDevice.current.batteryLevel, state: UIDevice.current.batteryState))
    }
}
