// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The processor makes each pad's feed with its dead zones and its route,
/// sends through the route the main actor resolved, and reads the records.
@MainActor
final class GamepadInputProcessorTests: XCTestCase {

    private func processor() -> GamepadInputProcessor {
        GamepadInputProcessor(untunedZones: GamepadInputProcessor.Deadzones())
    }

    func testTheRecordHoldsTheRawAndFilteredReportAndEveryAdmittedSample() throws {
        let processor = processor()
        processor.setDeadzones(deviceId: "pad", .init(stickFlat: 3000, triggerFlat: 10))
        let feed = processor.feed(for: "pad")
        let raw = GamepadReport(buttons: 1, lt: 5, rt: 200, lx: 2000, ly: -2000, rx: 9000, ry: 0)
        feed.publish(raw)
        let reported = try XCTUnwrap(processor.latestInput("pad"))
        XCTAssertEqual(reported.raw, raw)
        XCTAssertEqual(reported.filtered?.lx, 0, "the dead zone applied for the host")
        XCTAssertEqual(reported.filtered?.rx, 9000)
        XCTAssertEqual(reported.filtered?.lt, 0)
        XCTAssertEqual(reported.reports, 1)
        XCTAssertNil(reported.motion)
        let sample = MotionSample(gyroX: 1, gyroY: 2, gyroZ: 3, accelX: 4, accelY: 5, accelZ: 6)
        let refused = MotionSample(gyroX: 9, gyroY: 9, gyroZ: 9, accelX: 9, accelY: 9, accelZ: 9)
        feed.publishMotion(sample, nowNs: 1_000_000)
        feed.publishMotion(refused, nowNs: 1_000_001)
        XCTAssertEqual(processor.latestInput("pad")?.motion, sample, "a sample the rate limit refused is not recorded")
        XCTAssertEqual(processor.tallySnapshot().motion, ["pad": 1])
        let touch = TouchpadSample(finger0: TouchpadFinger(active: true, id: 3, x: -7, y: 8), finger1: .none, buttonPressed: true)
        feed.publishTouchpad(touch)
        XCTAssertEqual(processor.latestInput("pad")?.touch, touch)
        XCTAssertNil(processor.latestInput("other"), "a pad with no feed has no record")
    }

    func testPublishSendsTheStateThroughThePadsRoute() {
        let processor = processor()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        let state = GamepadReport(buttons: 0x1234, lt: 10, rt: 20, lx: 100, ly: -200, rx: 300, ry: -400)
        processor.feed(for: "pad-1").publish(state)
        XCTAssertEqual(recorder.reports.map(\.id), ["pad-1"])
        XCTAssertEqual(recorder.reports.map(\.report), [state])
        XCTAssertEqual(processor.sent.current(), 1)
    }

    func testAPadWithNoRouteSendsNothing() {
        let processor = processor()
        let recorder = InputRecorder()
        processor.route { deviceId in deviceId == "bound" ? recorder.route(deviceId) : nil }
        processor.feed(for: "unbound").publish(GamepadReport(buttons: 1))
        XCTAssertTrue(recorder.reports.isEmpty)
        XCTAssertEqual(processor.sent.current(), 0)
        processor.feed(for: "bound").publish(GamepadReport(buttons: 1))
        XCTAssertEqual(recorder.reports.map(\.id), ["bound"])
    }

    func testARouteChangeReachesAFeedMadeBeforeIt() {
        let processor = processor()
        let feed = processor.feed(for: "pad")
        feed.publish(GamepadReport(buttons: 1))
        let recorder = InputRecorder()
        processor.route(recorder.route)
        feed.publish(GamepadReport(buttons: 2))
        XCTAssertEqual(recorder.reports.map(\.report.buttons), [2], "the route arrives with the next report")
        XCTAssertTrue(processor.feed(for: "pad") === feed, "a pad keeps its feed")
    }

    func testZeroAndSendAllEmitsReleasedReportPerDevice() {
        let processor = processor()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        processor.feed(for: "a").publish(GamepadReport(buttons: 1))
        processor.feed(for: "b").publish(GamepadReport(buttons: 2))
        processor.zeroAndSendAll()
        let releases = recorder.reports.dropFirst(2)
        XCTAssertEqual(Set(releases.map(\.id)), ["a", "b"])
        XCTAssertTrue(releases.allSatisfy { $0.report == .released })
    }

    func testARemovedPadsFeedRoutesNowhereAndAReturningPadStartsOver() {
        let processor = processor()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        let gone = processor.feed(for: "pad")
        gone.publish(GamepadReport(buttons: 1))
        processor.remove(deviceId: "pad")
        gone.publish(GamepadReport(buttons: 2))
        XCTAssertEqual(recorder.reports.map(\.report.buttons), [1], "the old feed's route is gone")
        XCTAssertFalse(processor.feed(for: "pad") === gone, "a returning pad gets a fresh feed")
        XCTAssertEqual(processor.latestInput("pad")?.reports, 0)
    }

    // MARK: - Dead zones

    func testApplyDeadzonesZerosAtOrBelowAndPassesAboveAndNeverTouchesButtons() {
        let zones = GamepadInputProcessor.Deadzones(stickFlat: 100, triggerFlat: 10)
        let below = applyDeadzones(GamepadReport(buttons: 0xFFFF, lt: 10, rt: 10, lx: 100, ly: -100, rx: 50, ry: -50), zones)
        XCTAssertEqual(below, GamepadReport(buttons: 0xFFFF))
        let above = GamepadReport(buttons: 1, lt: 11, rt: 255, lx: 101, ly: -101, rx: .max, ry: .min)
        XCTAssertEqual(applyDeadzones(above, zones), above)
    }

    func testPublishAppliesDifferentDeadzonesPerDevice() {
        let processor = processor()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        processor.setDeadzones(deviceId: "a", .init(stickFlat: 1000, triggerFlat: 0))
        processor.setDeadzones(deviceId: "b", .init(stickFlat: 10, triggerFlat: 0))
        processor.feed(for: "a").publish(GamepadReport(lx: 500))
        processor.feed(for: "b").publish(GamepadReport(lx: 500))
        XCTAssertEqual(recorder.reports.map(\.report.lx), [0, 500])
    }

    func testDeadzonesSetBeforeAPadsFeedAreItsFromTheFirstReport() {
        let processor = processor()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        processor.setDeadzones(deviceId: "pad", .init(stickFlat: 1000, triggerFlat: 0))
        processor.feed(for: "pad").publish(GamepadReport(lx: 500))
        XCTAssertEqual(recorder.reports.map(\.report.lx), [0])
    }

    func testAnUntunedPadReadsTheDefaultsFromItsFirstReport() {
        let processor = GamepadInputProcessor()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        let defaults = DeadzoneSetting.defaults
        processor.feed(for: "pad").publish(GamepadReport(lt: defaults.triggerFlat, lx: defaults.stickFlat))
        XCTAssertEqual(recorder.reports.map(\.report), [GamepadReport()], "the defaults' flats read as zero")
    }

    // MARK: - Motion, touchpad and battery

    func testPublishMotionRateLimitsAt250HzMeasuredFromTheLastEmittedSample() {
        let processor = processor()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        let feed = processor.feed(for: "pad")
        let sample = MotionSample(gyroX: 1, gyroY: 0, gyroZ: 0, accelX: 0, accelY: 0, accelZ: 0)
        let interval = GamepadInputProcessor.motionMinIntervalNs
        for nowNs in [1000, 1000 + interval - 1, 1000 + interval, 1000 + interval + 1, 1000 + 2 * interval] {
            feed.publishMotion(sample, nowNs: nowNs)
        }
        XCTAssertEqual(recorder.motion.count, 3)
    }

    func testMotionAndTouchpadFollowTheRoutesSwitches() {
        let processor = processor()
        let recorder = InputRecorder(flags: ForwardingFlags(motion: false, touchpad: false))
        processor.route(recorder.route)
        let feed = processor.feed(for: "pad")
        feed.publishMotion(MotionSample(gyroX: 1, gyroY: 0, gyroZ: 0, accelX: 0, accelY: 0, accelZ: 0), nowNs: 1)
        feed.publishTouchpad(TouchpadSample(finger0: .none, finger1: .none, buttonPressed: true))
        XCTAssertTrue(recorder.sent.isEmpty, "switched off, recorded but not sent")
        XCTAssertNotNil(processor.latestInput("pad")?.touch)
    }

    func testPublishBatteryForwardsThroughTheRouteAndNotWithoutOne() {
        let processor = processor()
        let reading = BatteryReading(level: 84, state: .charging)
        processor.publishBattery(deviceId: "pad", reading: reading)
        let recorder = InputRecorder()
        processor.route(recorder.route)
        processor.publishBattery(deviceId: "pad", reading: reading)
        XCTAssertEqual(recorder.batteries.map(\.reading), [reading])
    }
}
