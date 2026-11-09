// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// An on-screen controller over a recording route, with the loop's ticker,
/// the clock and the motion sensor in the test's hands.
@MainActor
private struct RecordedPad {
    let recorder: InputRecorder
    let ticker = ManualTicker()
    let uptime = ManualUptime()
    let sensor: FakeMotionSensor
    let pad: OnScreenPad

    init(flags: ForwardingFlags = ForwardingFlags(), sensor: FakeMotionSensor = FakeMotionSensor()) {
        let recorder = InputRecorder(flags: flags)
        let processor = GamepadInputProcessor()
        processor.route(recorder.route)
        processor.setDeadzones(deviceId: onScreenSlotId, GamepadInputProcessor.Deadzones())
        self.recorder = recorder
        self.sensor = sensor
        pad = OnScreenPad(feed: processor.feed(for: onScreenSlotId), ticker: ticker, sensor: sensor, now: uptime.read)
    }

    /// One 50 ms tick of the resend loop.
    func tick(_ count: Int = 1) {
        for _ in 0 ..< count {
            uptime.advance(ticks: 1)
            ticker.fire()
        }
    }

    var reports: [GamepadReport] {
        recorder.reports.map(\.report)
    }

    var touches: [TouchpadSample] {
        recorder.touches.map(\.sample)
    }
}

private let pressedA = GamepadReport(buttons: WireButton.faceA.bit)

/// The on-screen controller's feed: touches leave as they happen through
/// the slot's route, the loop heals a lost edge with three resends and then
/// a keepalive, and closing releases everything.
@MainActor
final class OnScreenPadFeedTests: XCTestCase {

    func testATouchLeavesAtOnceThroughTheSlotsRoute() {
        let recorded = RecordedPad()
        recorded.pad.apply(.press(.faceA))
        XCTAssertEqual(recorded.recorder.reports.map(\.id), [onScreenSlotId])
        XCTAssertEqual(recorded.reports, [pressedA])
    }

    func testAMoveThatChangesNothingIsNotSentAgain() {
        let recorded = RecordedPad()
        recorded.pad.apply(.dpad(x: 1, y: 0))
        recorded.pad.apply(.dpad(x: 1, y: 0.1))
        XCTAssertEqual(recorded.reports.count, 1)
    }

    func testTheStickReachesTheWireWithNoDeadZone() {
        let recorded = RecordedPad()
        recorded.pad.apply(.stick(.left, x: 0.02, y: 0))
        XCTAssertEqual(recorded.reports.last?.lx, 655)
    }

    func testTheLoopResendsAChangeOnThreeTicksThenIdlesToAKeepalive() {
        let recorded = RecordedPad()
        recorded.pad.start()
        XCTAssertEqual(recorded.ticker.starts, [0.05], "the loop ticks every 50 ms")
        recorded.pad.apply(.press(.faceA))
        recorded.tick(3)
        XCTAssertEqual(recorded.reports, Array(repeating: pressedA, count: 4), "the event, then three resends")
        recorded.tick(19)
        XCTAssertEqual(recorded.reports.count, 4, "quiet until a second has passed")
        recorded.tick()
        XCTAssertEqual(recorded.reports.count, 5, "the keepalive")
    }

    func testAChangeRestartsTheBurst() {
        let recorded = RecordedPad()
        recorded.pad.start()
        recorded.pad.apply(.press(.faceA))
        recorded.tick(5)
        recorded.pad.apply(.release(.faceA))
        recorded.tick(3)
        XCTAssertEqual(recorded.reports.suffix(4), Array(repeating: GamepadReport.released, count: 4))
    }

    func testAScreenThatSentNothingResendsNothing() {
        let recorded = RecordedPad()
        recorded.pad.start()
        recorded.tick(30)
        XCTAssertEqual(recorded.recorder.sent, [])
    }

    func testClosingReleasesEverythingAndHealsTheReleaseBeforeTheLoopStops() {
        let recorded = RecordedPad()
        recorded.pad.start()
        recorded.pad.apply(.press(.faceA))
        recorded.pad.apply(.stick(.right, x: 1, y: 0))
        recorded.pad.touch(.finger(.first, x: 0, y: 0))
        recorded.tick(5)
        let before = recorded.reports.count
        recorded.pad.stop()
        XCTAssertEqual(recorded.reports.last, .released)
        XCTAssertEqual(recorded.touches.last, TouchpadSample.idle.lifting(id: 1))
        recorded.tick(3)
        XCTAssertEqual(recorded.reports.count, before + 4, "the release, then three resends")
        XCTAssertFalse(recorded.ticker.running, "the loop stops once the release is healed")
        recorded.tick(30)
        XCTAssertEqual(recorded.reports.count, before + 4)
    }

    func testTouchesLeaveAsTouchpadSamplesAndAWheelIsNeverResent() {
        let recorded = RecordedPad()
        recorded.pad.start()
        recorded.pad.touch(.leftButton(held: true))
        recorded.pad.touch(.scroll(points: -scrollPointsPerNotch))
        XCTAssertEqual(recorded.touches.map(\.buttonPressed), [true, true])
        XCTAssertEqual(recorded.touches.last?.scrollV, 120)
        recorded.tick(3)
        XCTAssertEqual(recorded.touches.suffix(3).map(\.scrollV), [0, 0, 0])
    }

    func testTheTouchStreamPacesOnItsOwn() {
        let recorded = RecordedPad()
        recorded.pad.start()
        recorded.pad.apply(.press(.faceA))
        recorded.tick(10)
        recorded.pad.touch(.finger(.first, x: 0, y: 0))
        recorded.tick(3)
        XCTAssertEqual(recorded.touches.count, 4, "a fresh touch spends its own burst")
    }

    func testATouchpadSwitchedOffSendsNoTouch() {
        let recorded = RecordedPad(flags: ForwardingFlags(touchpad: false))
        recorded.pad.touch(.finger(.first, x: 0, y: 0))
        XCTAssertEqual(recorded.touches, [])
    }

    func testMotionStreamsInThePadsFrameWhileOn() {
        let recorded = RecordedPad()
        recorded.pad.motion(true)
        recorded.sensor.feed(phoneAtRestTopLeft)
        let sample = recorded.recorder.motion.last?.sample
        XCTAssertEqual(sample?.accelY, scaleAccel(1), "a phone at rest reads one g up")
        recorded.pad.motion(false)
        XCTAssertFalse(recorded.sensor.running)
    }

    func testClosingStopsTheMotion() {
        let recorded = RecordedPad()
        recorded.pad.start()
        recorded.pad.motion(true)
        recorded.pad.stop()
        XCTAssertFalse(recorded.sensor.running)
        XCTAssertFalse(recorded.pad.motionRunning)
    }

    func testADigitalTriggerKindMakesARailAFullPress() {
        let recorded = RecordedPad()
        recorded.pad.useAnalogTriggers(false)
        recorded.pad.apply(.trigger(.left, railY: 0.9))
        XCTAssertEqual(recorded.reports.last?.lt, 255)
    }
}

private extension TouchpadSample {
    /// A released sample whose first finger lifted with `id`.
    func lifting(id: UInt8) -> TouchpadSample {
        TouchpadSample(finger0: TouchpadFinger(active: false, id: id, x: 0, y: 0), finger1: finger1, buttonPressed: false)
    }
}
