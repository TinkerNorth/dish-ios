// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// The fleet's battery rule: the pad's own battery and the device's compete,
/// the host is sent the lower and the card keeps the pad's. The reducer takes
/// no link, so a wired pad that reports its charge competes like any other.
final class BatteryRoutingTests: XCTestCase {

    private let device = BatteryReading(level: 60, state: .discharging)

    func testAPadLowerThanTheDeviceSendsItsOwnReading() {
        let pad = BatteryReading(level: 20, state: .discharging)
        XCTAssertEqual(routeBattery(pad: pad, device: device).wire, pad)
    }

    func testAPadHigherThanTheDeviceSendsTheDevicesReading() {
        let pad = BatteryReading(level: 90, state: .discharging)
        XCTAssertEqual(routeBattery(pad: pad, device: device).wire, device)
    }

    func testAPadWithNoBatterySendsTheDevicesReading() {
        XCTAssertEqual(routeBattery(pad: nil, device: device).wire, device)
    }

    func testAnUnknownDeviceAndAKnownPadSendThePadsReading() {
        let pad = BatteryReading(level: 75, state: .discharging)
        XCTAssertEqual(routeBattery(pad: pad, device: nil).wire, pad, "a device that reports nothing")
        XCTAssertEqual(
            routeBattery(pad: pad, device: BatteryReading(level: nil, state: .charging)).wire,
            pad,
            "a device whose level is unknown sorts above any known level"
        )
    }

    func testAPadWhoseLevelIsUnknownSendsTheDevicesReading() {
        let pad = BatteryReading(level: nil, state: .charging)
        XCTAssertEqual(routeBattery(pad: pad, device: device).wire, device)
    }

    func testATieGoesToThePad() {
        let pad = BatteryReading(level: 60, state: .charging)
        XCTAssertEqual(routeBattery(pad: pad, device: device).wire, pad)
        let unknownPad = BatteryReading(level: nil, state: .full)
        XCTAssertEqual(
            routeBattery(pad: unknownPad, device: BatteryReading(level: nil, state: .discharging)).wire,
            unknownPad,
            "two unknown levels tie"
        )
    }

    func testTheChargeStateTravelsWithTheLevelThatWon() {
        let lowCharging = BatteryReading(level: 30, state: .charging)
        let full = BatteryReading(level: 100, state: .full)
        XCTAssertEqual(routeBattery(pad: lowCharging, device: full).wire, lowCharging)
        XCTAssertEqual(routeBattery(pad: full, device: lowCharging).wire, lowCharging, "never the pad's level under the device's state")
    }

    func testNoReadingOnEitherSideSendsNothing() {
        XCTAssertNil(routeBattery(pad: nil, device: nil).wire)
    }

    func testTheCardKeepsThePadsOwnReadingWhicheverIsSent() {
        let pad = BatteryReading(level: 90, state: .discharging)
        XCTAssertEqual(routeBattery(pad: pad, device: device).display, pad, "the host gets the device's, the card the pad's")
        XCTAssertNil(routeBattery(pad: nil, device: device).display, "a pad with no battery shows none")
    }

    func testALevelIsAPercentAndANegativeLevelIsNone() {
        XCTAssertEqual(batteryPercent(0.84), 84)
        XCTAssertEqual(batteryPercent(0.846), 85, "rounded to the nearest percent")
        XCTAssertEqual(batteryPercent(1.2), 100, "clamped")
        XCTAssertNil(batteryPercent(-1))
    }
}
