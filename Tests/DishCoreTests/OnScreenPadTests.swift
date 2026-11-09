// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// Every control of the on-screen gamepad becomes the report a physical pad
/// would send: buttons, both sticks centre-origin and clamped to the rim,
/// the rails, the d-pad's eight directions, and a release of everything.
final class OnScreenPadTests: XCTestCase {

    private func after(_ events: OnScreenPadEvent..., from start: OnScreenPadState = OnScreenPadState()) -> OnScreenPadState {
        events.reduce(start, reduceOnScreenPad)
    }

    func testAFreshPadIsTheReleasedReport() {
        XCTAssertEqual(OnScreenPadState().report, .released)
    }

    func testEveryButtonSetsItsOwnBitAndClearsItOnRelease() {
        let buttons: [WireButton] = [
            .faceA,
            .faceB,
            .faceX,
            .faceY,
            .leftShoulder,
            .rightShoulder,
            .leftThumb,
            .rightThumb,
            .start,
            .back,
            .guide
        ]
        for button in buttons {
            XCTAssertEqual(after(.press(button)).report.buttons, button.bit, "\(button)")
            XCTAssertEqual(after(.press(button), .release(button)).report, .released, "\(button)")
        }
    }

    func testTwoButtonsHeldTogetherBothRideTheReport() {
        let state = after(.press(.faceA), .press(.rightShoulder), .release(.faceA))
        XCTAssertEqual(state.report.buttons, WireButton.rightShoulder.bit)
    }

    func testAStickPushedUpOnScreenReadsUpOnTheWire() {
        let report = after(.stick(.left, x: 0, y: -1)).report
        XCTAssertEqual(report.lx, 0)
        XCTAssertEqual(report.ly, 32767)
    }

    func testTheRightStickMovesTheRightAxesOnly() {
        let report = after(.stick(.right, x: 0.5, y: 0.5)).report
        XCTAssertEqual(report.lx, 0)
        XCTAssertEqual(report.ly, 0)
        XCTAssertEqual(report.rx, 16383)
        XCTAssertEqual(report.ry, -16383)
    }

    func testAFingerPastTheRimIsClampedAlongItsOwnDirection() {
        let report = after(.stick(.left, x: 3, y: 4)).report
        XCTAssertEqual(report.lx, Int16(0.6 * 32767), accuracy: 1)
        XCTAssertEqual(report.ly, Int16(-0.8 * 32767), accuracy: 1)
    }

    func testAStickHasNoDeadZoneOfItsOwn() {
        XCTAssertEqual(after(.stick(.left, x: 0.01, y: 0)).report.lx, 327)
    }

    func testAReleasedStickReturnsToCentre() {
        XCTAssertEqual(after(.stick(.left, x: 1, y: 0), .stickReleased(.left)).report, .released)
    }

    func testTheTopQuarterOfARailIsAFullPull() {
        XCTAssertEqual(after(.trigger(.left, railY: 0.1)).report.lt, 255)
        XCTAssertEqual(after(.trigger(.right, railY: 0.25)).report.rt, 255)
    }

    func testBelowTheFullZoneARailRampsToNothingAtItsBottom() {
        XCTAssertEqual(after(.trigger(.right, railY: 0.625)).report.rt, 128)
        XCTAssertEqual(after(.trigger(.right, railY: 1)).report.rt, 0)
    }

    func testAFingerDraggedOffARailIsClampedToItsEdge() {
        XCTAssertEqual(after(.trigger(.left, railY: -2)).report.lt, 255)
        XCTAssertEqual(after(.trigger(.left, railY: 3)).report.lt, 0)
    }

    func testADigitalTriggerIsAFullPressWhereverItIsTouched() {
        let state = after(.trigger(.left, railY: 0.9), from: OnScreenPadState(analogTriggers: false))
        XCTAssertEqual(state.report.lt, 255)
    }

    func testAReleasedRailLetsGo() {
        XCTAssertEqual(after(.trigger(.left, railY: 0), .triggerReleased(.left)).report, .released)
    }

    func testTheDpadReadsTheNearerArm() {
        XCTAssertEqual(after(.dpad(x: 1, y: 0.1)).report.buttons, WireButton.dpadRight.bit)
        XCTAssertEqual(after(.dpad(x: -1, y: 0)).report.buttons, WireButton.dpadLeft.bit)
        XCTAssertEqual(after(.dpad(x: 0.1, y: -1)).report.buttons, WireButton.dpadUp.bit)
        XCTAssertEqual(after(.dpad(x: 0, y: 1)).report.buttons, WireButton.dpadDown.bit)
    }

    func testTheDpadReadsADiagonalOnceTheMinorAxisReachesThirtyPercent() {
        let downRight = WireButton.dpadDown.bit | WireButton.dpadRight.bit
        let upLeft = WireButton.dpadUp.bit | WireButton.dpadLeft.bit
        XCTAssertEqual(after(.dpad(x: 1, y: 0.3)).report.buttons, downRight)
        XCTAssertEqual(after(.dpad(x: -0.5, y: -0.5)).report.buttons, upLeft)
        XCTAssertEqual(after(.dpad(x: 1, y: 0.29)).report.buttons, WireButton.dpadRight.bit)
    }

    func testSlidingAcrossTheDpadMovesFromOneArmToTheNext() {
        let state = after(.dpad(x: 1, y: 0), .dpad(x: 0, y: -1))
        XCTAssertEqual(state.report.buttons, WireButton.dpadUp.bit)
    }

    func testTheDpadsDeadCentreAndItsReleaseHoldNothing() {
        XCTAssertEqual(after(.dpad(x: 0, y: 0)).report, .released)
        XCTAssertEqual(after(.dpad(x: 1, y: 0), .dpadReleased).report, .released)
    }

    func testTheDpadLeavesTheOtherButtonsAlone() {
        let state = after(.press(.faceA), .dpad(x: 1, y: 0), .dpadReleased)
        XCTAssertEqual(state.report.buttons, WireButton.faceA.bit)
    }

    func testReleasingEverythingCentresTheWholePadAndKeepsTheTriggerKind() {
        let held = after(
            .press(.faceA),
            .stick(.left, x: 1, y: 0),
            .stick(.right, x: 0, y: 1),
            .trigger(.left, railY: 0),
            .trigger(.right, railY: 0),
            .dpad(x: 1, y: 0),
            from: OnScreenPadState(analogTriggers: false)
        )
        XCTAssertNotEqual(held.report, .released)
        let released = after(.releaseAll, from: held)
        XCTAssertEqual(released.report, .released)
        XCTAssertFalse(released.analogTriggers)
    }
}

private func XCTAssertEqual(_ value: Int16, _ expected: Int16, accuracy: Int16, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertLessThanOrEqual(abs(Int(value) - Int(expected)), Int(accuracy), "\(value) is not \(expected)", file: file, line: line)
}
