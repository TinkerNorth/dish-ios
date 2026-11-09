// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// A pad's feed: its record packs every value bit for bit, the main actor
/// never reads a record half written, a route posted while the pad sends
/// reaches it, and a report that repeats the last one let through is dropped.
@MainActor
final class PadFeedTests: XCTestCase {

    private func zeroZones() -> GamepadInputProcessor {
        GamepadInputProcessor(untunedZones: GamepadInputProcessor.Deadzones())
    }

    func testEveryRecordedValueReadsBackBitForBit() {
        let reports = [
            GamepadReport(buttons: 0xFFFF, lt: 255, rt: 0, lx: .min, ly: .max, rx: -1, ry: 0),
            GamepadReport(buttons: 0x8001, lt: 1, rt: 254, lx: 1, ly: -1, rx: .max, ry: .min),
            .released
        ]
        for report in reports {
            XCTAssertEqual(GamepadReport(packedLow: report.packedLow, high: report.packedHigh), report)
        }
        let motion = MotionSample(gyroX: .min, gyroY: .max, gyroZ: -1, accelX: 1, accelY: -32000, accelZ: 32000)
        XCTAssertEqual(MotionSample(packedLow: motion.packedLow, high: motion.packedHigh), motion)
        let touch = TouchpadSample(
            finger0: TouchpadFinger(active: true, id: 255, x: .min, y: .max),
            finger1: TouchpadFinger(active: false, id: 1, x: -1, y: 1),
            buttonPressed: true
        )
        XCTAssertEqual(TouchpadSample(packedLow: touch.packedLow, high: touch.packedHigh), touch)
        let zones = GamepadInputProcessor.Deadzones(stickFlat: -5, triggerFlat: 255)
        XCTAssertEqual(GamepadInputProcessor.Deadzones(packed: zones.packed), zones)
    }

    /// The pad's thread writes reports whose fields all carry one number;
    /// the main actor reads the record meanwhile. A read that mixed two
    /// writes would hold two numbers.
    func testTheMainActorNeverReadsARecordHalfWritten() {
        let processor = zeroZones()
        let feed = processor.feed(for: "pad")
        let done = DispatchSemaphore(value: 0)
        let writes = 20000
        Thread {
            for step in 1 ... writes {
                let value = Int16(truncatingIfNeeded: step)
                feed.publish(GamepadReport(buttons: UInt16(bitPattern: value), lx: value, ly: value, rx: value, ry: value))
            }
            done.signal()
        }.start()
        var reads = 0
        while done.wait(timeout: .now()) == .timedOut {
            guard let input = processor.latestInput("pad"), let raw = input.raw else { continue }
            reads += 1
            XCTAssertEqual(Set([raw.lx, raw.ly, raw.rx, raw.ry, Int16(bitPattern: raw.buttons)]).count, 1, "one write's fields")
            XCTAssertEqual(input.filtered, raw, "no dead zone, so the host's view is the pad's")
        }
        XCTAssertGreaterThan(reads, 0)
        XCTAssertEqual(processor.latestInput("pad")?.reports, UInt64(writes))
    }

    /// A route posted from the main actor while another thread publishes
    /// reaches that thread with one of its next reports.
    func testARoutePostedWhileThePadSendsReachesIt() {
        let processor = zeroZones()
        let feed = processor.feed(for: "pad")
        let recorder = InputRecorder()
        let stop = AtomicBool(false)
        let stopped = DispatchSemaphore(value: 0)
        Thread {
            while !stop.get() {
                feed.publish(GamepadReport(buttons: 1))
            }
            stopped.signal()
        }.start()
        processor.route(recorder.route)
        let deadline = Date().addingTimeInterval(5)
        while recorder.reports.isEmpty, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.001))
        }
        stop.set(true)
        XCTAssertEqual(stopped.wait(timeout: .now() + 5), .success)
        XCTAssertFalse(recorder.reports.isEmpty, "the sending thread took the route")
    }

    func testTwoPadsPublishingAtOnceKeepTheirOwnRecords() {
        let processor = zeroZones()
        let pads = [processor.feed(for: "a"), processor.feed(for: "b")]
        let reports = 5000
        let group = DispatchGroup()
        for (number, feed) in pads.enumerated() {
            group.enter()
            Thread {
                for step in 1 ... reports {
                    feed.publish(GamepadReport(buttons: UInt16(number + 1), lx: Int16(truncatingIfNeeded: step)))
                }
                group.leave()
            }.start()
        }
        XCTAssertEqual(group.wait(timeout: .now() + 20), .success)
        XCTAssertEqual(processor.tallySnapshot().reports, ["a": UInt64(reports), "b": UInt64(reports)])
        XCTAssertEqual(processor.latestInput("a")?.raw?.buttons, 1)
        XCTAssertEqual(processor.latestInput("b")?.raw?.buttons, 2)
        XCTAssertEqual(processor.latestInput("a")?.raw?.lx, Int16(truncatingIfNeeded: reports))
    }

    func testAReportThatRepeatsTheLastOneLetThroughIsDropped() {
        let processor = zeroZones()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        let feed = processor.feed(for: "pad")
        for buttons: UInt16 in [1, 1, 1, 2, 2, 1, 0, 0] {
            feed.publishIfChanged(GamepadReport(buttons: buttons))
        }
        XCTAssertEqual(recorder.reports.map(\.report.buttons), [1, 2, 1, 0])
    }

    /// The wire's motion frame carries the time since the pad's last sample
    /// let through: zero for the first, then the window between them.
    func testMotionCarriesTheDeltaSinceTheLastSampleLetThrough() {
        let processor = zeroZones()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        let feed = processor.feed(for: "pad")
        let sample = MotionSample(gyroX: 1, gyroY: 0, gyroZ: 0, accelX: 0, accelY: 0, accelZ: 0)
        let window = GamepadInputProcessor.motionMinIntervalNs
        feed.publishMotion(sample, nowNs: 1_000_000)
        feed.publishMotion(sample, nowNs: 1_000_000 + window / 2)
        feed.publishMotion(sample, nowNs: 1_000_000 + window * 3)
        XCTAssertEqual(recorder.stamps, [.motionDeltaUs(0), .motionDeltaUs(UInt32(window * 3 / 1000))])
    }

    /// GameController gives a touch no timestamp of its own, so the feed
    /// stamps the instant it publishes, in milliseconds.
    func testATouchIsStampedWithItsPublishInstant() {
        let processor = zeroZones()
        let recorder = InputRecorder()
        processor.route(recorder.route)
        let feed = processor.feed(for: "pad")
        feed.publishTouchpad(TouchpadSample(finger0: .none, finger1: .none, buttonPressed: true), nowNs: 7_250_000_000)
        XCTAssertEqual(recorder.stamps, [.touchTimeMs(7250)])
    }

    func testTheFingersIdsBumpOnEachFreshContactPerFinger() {
        let feed = zeroZones().feed(for: "pad")
        XCTAssertTrue(feed.advanceTouchIds(finger0Active: true, finger1Active: false) == (1, 0))
        XCTAssertTrue(feed.advanceTouchIds(finger0Active: true, finger1Active: true) == (1, 1))
        XCTAssertTrue(feed.advanceTouchIds(finger0Active: false, finger1Active: true) == (1, 1))
        XCTAssertTrue(feed.advanceTouchIds(finger0Active: true, finger1Active: false) == (2, 1))
    }

    func testTheFingersWordReadsBackBitForBit() {
        let contacts = FingerContacts(
            finger0: FingerContact(wasActive: true, id: 255),
            finger1: FingerContact(wasActive: false, id: 7)
        )
        XCTAssertEqual(FingerContacts(packed: contacts.packed), contacts)
    }
}
