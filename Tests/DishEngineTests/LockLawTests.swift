// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// The locks each hot thread takes, read off the production objects running
/// in their roles: a pad publishing reports, motion and touches on an input
/// queue, a receive thread posting rumble and light-bar commands through a
/// connection's feedback routes, the feedback queue draining them, and the
/// main actor republishing the routing table every 100 ms and reading the
/// tally. The lists are a ratchet: a lock that appears fails, and so does a
/// listed one no longer observed until it is deleted. Today every list is
/// empty: no hot thread takes a lock. The sender's own run joins this one
/// when the network wave lands.
@MainActor
final class LockLawTests: XCTestCase {

    #if LOCK_STATS
    func testEachHotThreadTakesExactlyTheLocksOnItsList() {
        let run = runTheHotPaths()
        XCTAssertGreaterThan(run.reports, 0, "the pad's reports reached the sink")
        XCTAssertGreaterThan(run.actuations, 0, "the feedback reached the actuators")
        XCTAssertGreaterThan(run.tallied, 0, "the main actor read the tally")
        let main = run.snapshot.acquired(by: .main)
        XCTAssertTrue(main.contains("routing.table"), "the run exercised a tracked lock, so an empty list means something")
        expectExactly("Input may acquire", observed: run.snapshot.acquired(by: .input), listed: [])
        expectExactly("Receive may acquire", observed: run.snapshot.acquired(by: .receive), listed: [])
        expectExactly("Feedback may acquire", observed: run.snapshot.acquired(by: .feedback), listed: [])
        expectExactly("held across a blocking call", observed: Set(run.snapshot.blocking.keys.map(label)), listed: [])
        expectExactly("taken inside another", observed: Set(run.snapshot.edges.keys.map(label)), listed: [])
    }

    private struct HotRun {
        let snapshot: LockStatsSnapshot
        let reports: Int
        let actuations: Int
        let tallied: UInt64
    }

    private func runTheHotPaths() -> HotRun {
        let processor = GamepadInputProcessor()
        let routing = InputRouting()
        let recorder = InputRecorder()
        let actuators = RecordingActuators()
        let feedback = PadFeedback(actuators: actuators, queue: ThreadRole.feedback.queue(label: "test.feedback", qos: .userInteractive))
        let snapshot = RoutingSnapshot(
            bySlot: ["pad": recorder.route("pad")].compactMapValues { $0 },
            bySatellitePad: [SatellitePadKey(connectionId: "sat", controllerIndex: 0): BoundSlotRoute(
                slotId: "pad",
                flags: ForwardingFlags()
            )]
        )
        let routes = FeedbackRoutes(connectionId: "sat", snapshot: snapshot, global: ForwardingFlags(), feedback: feedback)
        routing.publish(snapshot, to: processor)
        let feed = processor.feed(for: "pad")
        let queue = ThreadRole.input.queue(label: "test.input", qos: .userInteractive)
        resetLockStats()
        let group = DispatchGroup()
        startInputProducer(feed, queue: queue, group: group)
        startFeedbackSender(routes, group: group)
        var tallied: UInt64 = 0
        var tick = 0
        let giveUp = Date().addingTimeInterval(LockLawRun.limitSeconds)
        while tick < LockLawRun.mainTicks || group.wait(timeout: .now()) == .timedOut, Date() < giveUp {
            routing.republish(to: processor)
            tallied = processor.tallySnapshot().reports["pad"] ?? 0
            RunLoop.main.run(until: Date().addingTimeInterval(LockLawRun.mainTickSeconds))
            tick += 1
        }
        XCTAssertEqual(group.wait(timeout: .now()), .success, "the producers finished")
        feedback.queue.sync {}
        return HotRun(
            snapshot: lockStatsSnapshot(),
            reports: recorder.reports.count,
            actuations: actuators.actuations.count,
            tallied: tallied
        )
    }

    private func startInputProducer(_ feed: PadFeed, queue: DispatchSerialQueue, group: DispatchGroup) {
        group.enter()
        startThread {
            for frame in 0 ..< LockLawRun.frames {
                queue.async { publishFrame(frame, on: feed) }
                Thread.sleep(forTimeInterval: LockLawRun.frameSeconds)
            }
            queue.async { group.leave() }
        }
    }

    private func startFeedbackSender(_ routes: FeedbackRoutes, group: DispatchGroup) {
        group.enter()
        startThread {
            ThreadRole.receive.enterThread()
            for tick in 0 ..< LockLawRun.rumbleTicks {
                routes.rumble(controllerIndex: 0, strong: 30000, weak: 10000, durationMs: 100)
                if tick % LockLawRun.lightbarEvery == 0 {
                    routes.lightbar(controllerIndex: 0, red: 0, green: 64, blue: 255)
                }
                Thread.sleep(forTimeInterval: LockLawRun.rumbleSeconds)
            }
            group.leave()
        }
    }

    private func expectExactly(_ law: String, observed: Set<String>, listed: Set<String>) {
        for name in observed.subtracting(listed).sorted() {
            XCTFail("\(law): \(name) is not on the list")
        }
        for name in listed.subtracting(observed).sorted() {
            XCTFail("\(law): \(name) is listed but no longer observed; delete it")
        }
    }

    private func label(_ pair: LockPair) -> String {
        "\(pair.first) > \(pair.second)"
    }
    #else
    func testTheLawsNeedTheLockStatsBuild() throws {
        throw XCTSkip("built without LOCK_STATS; build with SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) LOCK_STATS'")
    }
    #endif
}

#if LOCK_STATS
/// The run's shape: long enough for many main-actor republishes to land
/// while the pad and the receive thread are busy.
private enum LockLawRun {
    static let limitSeconds: TimeInterval = 60
    static let frames = 2000
    static let frameSeconds = 0.001
    static let mainTicks = 25
    static let mainTickSeconds = 0.1
    static let rumbleTicks = 220
    static let rumbleSeconds = 0.01
    static let lightbarEvery = 10
}

/// A producer at the input queue's quality of service, as a pad's are.
private func startThread(_ body: @escaping @Sendable () -> Void) {
    let thread = Thread(block: body)
    thread.qualityOfService = .userInteractive
    thread.start()
}

/// One input-queue event as GameController delivers them: a report, and on
/// every fourth a motion sample, on every eighth a touch.
private func publishFrame(_ frame: Int, on feed: PadFeed) {
    feed.publishIfChanged(GamepadReport(rx: Int16(truncatingIfNeeded: frame)))
    if frame % 4 == 0 {
        feed.publishMotion(MotionSample(gyroX: 10, gyroY: 0, gyroZ: 0, accelX: 0, accelY: 0, accelZ: 8192))
    }
    if frame % 8 == 0 {
        let finger = TouchpadFinger(active: true, id: 1, x: 1000, y: -1000)
        feed.publishTouchpad(TouchpadSample(finger0: finger, finger1: .none, buttonPressed: false))
    }
}
#endif
