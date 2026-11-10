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
/// tally; and the satellite path's own run, a pad routed to a live client,
/// its heartbeat, and its receive loop opening a loopback satellite's
/// return commands; and the Moonlight path's own run, a pad routed to a
/// host's link, the control socket's queue opening the host's events, and
/// the session's clock. The lists are a ratchet: a lock that appears fails,
/// and so does a listed one no longer observed until it is deleted. No
/// satellite hot thread takes a lock; the heartbeat takes the latency
/// window's. The Moonlight path's threads hold the session's lock for the
/// ENet bookkeeping, by design, and the link's and the feedback path's as
/// debt, as dish-mac's do.
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

    /// The satellite path: the pad's reports leave through the client on
    /// the input queue, the receive thread opens the return commands and
    /// posts them to the pad's feedback, and the heartbeat beats; none of
    /// them takes a tracked lock but the heartbeat, which arms the latency
    /// window's ping clock under its lock, as dish-mac's does.
    func testTheSatellitesThreadsTakeExactlyTheLocksOnTheirLists() throws {
        let run = try LockLawSatelliteRun.run()
        XCTAssertGreaterThan(run.uplinks, 1, "the pad's reports and the heartbeats reached the satellite")
        XCTAssertGreaterThan(run.downlinks, 0, "the satellite answered")
        XCTAssertGreaterThan(run.actuations, 0, "the return commands reached the actuators")
        XCTAssertGreaterThan(run.latencySamples, 0, "the acks paired with the heartbeat's pings")
        let snapshot = run.snapshot
        XCTAssertTrue(snapshot.acquired(by: .main).contains("satellite.latency"), "the main actor read the window under its lock")
        expectExactly("Input may acquire", observed: snapshot.acquired(by: .input), listed: [])
        expectExactly("Receive may acquire", observed: snapshot.acquired(by: .receive), listed: [])
        expectExactly("Feedback may acquire", observed: snapshot.acquired(by: .feedback), listed: [])
        expectExactly("Heartbeat may acquire", observed: snapshot.acquired(by: .heartbeat), listed: ["satellite.latency"])
        expectExactly("held across a blocking call", observed: Set(snapshot.blocking.keys.map(label)), listed: [])
        expectExactly("taken inside another", observed: Set(snapshot.edges.keys.map(label)), listed: [])
    }

    /// The Moonlight path: the pad's reports, motion and touches leave
    /// through the host's link on the input queue, the control socket's
    /// queue acknowledges the host and opens its rumble, light and motion
    /// requests into the pad's feedback, and the session's clock ticks the
    /// ENet bookkeeping; the main actor rebuilds the feedback routes under
    /// their lock.
    func testTheMoonlightThreadsTakeExactlyTheLocksOnTheirLists() async throws {
        let run = try await LockLawMoonlightRun.run()
        XCTAssertGreaterThan(run.frames, 0, "the pad's frames reached the host")
        XCTAssertGreaterThan(run.motions, 0, "the host asked for motion and got it")
        XCTAssertGreaterThan(run.rumbles, 0, "the host's rumble reached the actuators")
        XCTAssertGreaterThan(run.lamps, 0, "the host's light reached the actuators")
        let snapshot = run.snapshot
        XCTAssertTrue(
            snapshot.acquired(by: .main).contains("moonlight.feedbackRoutes"),
            "the main actor rebuilt the routes under their lock"
        )
        expectExactly(
            "Input may acquire on the Moonlight path",
            observed: snapshot.acquired(by: .input),
            listed: MoonlightLockLaws.inputMayAcquire
        )
        expectExactly(
            "MoonlightUdp may acquire",
            observed: snapshot.acquired(by: .moonlightUdp),
            listed: MoonlightLockLaws.moonlightUdpMayAcquire
        )
        expectExactly(
            "Heartbeat may acquire on the Moonlight path",
            observed: snapshot.acquired(by: .heartbeat),
            listed: MoonlightLockLaws.heartbeatMayAcquire
        )
        expectExactly("Feedback may acquire on the Moonlight path", observed: snapshot.acquired(by: .feedback), listed: [])
        expectExactly("held across a blocking call on the Moonlight path", observed: Set(snapshot.blocking.keys.map(label)), listed: [])
        expectExactly("taken inside another on the Moonlight path", observed: Set(snapshot.edges.keys.map(label)), listed: [])
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
            bySlot: ["pad": recorder.route("pad"), onScreenSlotId: recorder.route(onScreenSlotId)].compactMapValues { $0 },
            bySatellitePad: [SatellitePadKey(connectionId: "sat", controllerIndex: 0): BoundSlotRoute(
                slotId: "pad",
                flags: ForwardingFlags()
            )]
        )
        let routes = FeedbackRoutes(connectionId: "sat", snapshot: snapshot, global: ForwardingFlags(), feedback: feedback)
        routing.publish(snapshot, to: processor)
        let feed = processor.feed(for: "pad")
        let onScreen = processor.feed(for: onScreenSlotId)
        let queue = ThreadRole.input.queue(label: "test.input", qos: .userInteractive)
        resetLockStats()
        let group = DispatchGroup()
        startInputProducer(feed, onScreen: onScreen, queue: queue, group: group)
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

    private func startInputProducer(_ feed: PadFeed, onScreen: PadFeed, queue: DispatchSerialQueue, group: DispatchGroup) {
        group.enter()
        startThread {
            for frame in 0 ..< LockLawRun.frames {
                queue.async {
                    publishFrame(frame, on: feed)
                    publishOnScreenFrame(frame, on: onScreen)
                }
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
/// Today's locks on the Moonlight path, exactly, from its own run.
private enum MoonlightLockLaws {
    /// The link's table under its lock, then the session's ENet bookkeeping:
    /// the report is sealed before it and only framed and tracked under it.
    static let inputMayAcquire: Set = ["moonlight.padLink", "moonlight.session"]
    /// The acknowledgements and the payloads come out under the session's
    /// lock and the open is after it; the handler, the mixes and the routes
    /// are the feedback path's, the link's is a motion request landing.
    static let moonlightUdpMayAcquire: Set = [
        "moonlight.feedbackHandler",
        "moonlight.feedbackRoutes",
        "moonlight.padLink",
        "moonlight.rumbleMixes",
        "moonlight.session"
    ]
    /// The clock retransmits and keeps alive under the session's lock.
    static let heartbeatMayAcquire: Set = ["moonlight.session"]
}

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

/// The on-screen controller's path on the same thread: a stick through its
/// reducer and a finger through the touch surface's, out through its feed.
private func publishOnScreenFrame(_ frame: Int, on feed: PadFeed) {
    let travel = Float(frame % 100) / 100
    feed.publishIfChanged(reduceOnScreenPad(OnScreenPadState(), .stick(.left, x: travel, y: 0)).report)
    if frame % 8 == 0 {
        feed.publishTouchpad(reduceTouchSurface(TouchSurfaceState(), .finger(.first, x: travel, y: 0)).sample)
    }
}
#endif
