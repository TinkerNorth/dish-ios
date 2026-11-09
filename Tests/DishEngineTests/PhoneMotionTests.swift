// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The iPhone held on its side is a pad: its axes turn into the pad's on
/// whichever side it lies, and the side follows gravity as iOS's own
/// orientation does, holding while the phone lies flat.
final class PhoneMotionTests: XCTestCase {

    private let still = MotionAxes.zero

    func testAPhoneAtRestOnEitherSideReadsOneGUp() {
        let topLeft = phoneMotionToWire(phoneAtRestTopLeft, side: .topLeft)
        let topRight = phoneMotionToWire(
            DeviceMotionReading(rotationRate: still, gravity: MotionAxes(x: 1, y: 0, z: 0), userAcceleration: still),
            side: .topRight
        )
        for sample in [topLeft, topRight] {
            XCTAssertEqual(sample.accelX, 0)
            XCTAssertEqual(sample.accelY, scaleAccel(1))
            XCTAssertEqual(sample.accelZ, 0)
        }
    }

    func testTheLongSideIsThePadsXAxisPointingAwayFromThePhonesTop() {
        let axes = MotionAxes(x: 0, y: 1, z: 0)
        XCTAssertEqual(padAxes(axes, side: .topLeft), MotionAxes(x: -1, y: 0, z: 0))
        XCTAssertEqual(padAxes(axes, side: .topRight), MotionAxes(x: 1, y: 0, z: 0))
    }

    func testTheScreensNormalStaysTowardThePlayer() {
        let axes = MotionAxes(x: 0, y: 0, z: 1)
        XCTAssertEqual(padAxes(axes, side: .topLeft).z, 1)
        XCTAssertEqual(padAxes(axes, side: .topRight).z, 1)
    }

    func testARotationTurnsWithTheAxes() {
        let rate = MotionAxes(x: Double.pi, y: 0, z: 0)
        let sample = phoneMotionToWire(DeviceMotionReading(rotationRate: rate, gravity: still, userAcceleration: still), side: .topLeft)
        XCTAssertEqual(sample.gyroX, 0)
        XCTAssertEqual(sample.gyroY, scaleGyro(180))
    }

    func testTheSideFollowsGravityAlongTheLongEdge() {
        XCTAssertEqual(landscapeSide(previous: .topRight, gravityX: -0.9), .topLeft)
        XCTAssertEqual(landscapeSide(previous: .topLeft, gravityX: 0.9), .topRight)
    }

    func testAPhoneLyingFlatKeepsTheSideItHad() {
        XCTAssertEqual(landscapeSide(previous: .topRight, gravityX: -0.2), .topRight)
        XCTAssertEqual(landscapeSide(previous: .topLeft, gravityX: 0.4), .topLeft)
    }

    func testThePhoneRumblesWithTheStrongerMotor() {
        XCTAssertEqual(phoneRumbleMagnitude(strong: 40000, weak: 10000), 40000)
        XCTAssertEqual(phoneRumbleMagnitude(strong: 0, weak: 20000), 20000)
    }
}
