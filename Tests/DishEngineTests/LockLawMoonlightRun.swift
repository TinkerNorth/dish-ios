// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

#if LOCK_STATS
import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// The Moonlight path's run for `LockLawTests`: the real manager paired
/// with a host on the loopback and streaming to it over the real sockets, a
/// pad publishing on the input queue through its route to the host's link,
/// the host's control port acknowledged and its rumble, light and
/// motion-request events opened on the control socket's queue into the
/// pad's feedback, the session's clock ticking, and the main actor
/// republishing the routes every 100 ms.
@MainActor
struct LockLawMoonlightRun {
    let snapshot: LockStatsSnapshot
    let frames: Int
    let motions: Int
    let rumbles: Int
    let lamps: Int

    static func run() async throws -> LockLawMoonlightRun {
        guard let client = MoonlightIdentityFixtures.client(), let hostIdentity = MoonlightIdentityFixtures.host(),
              let tls = hostIdentity.secIdentity() else
        {
            throw XCTSkip("the PKCS#12 identities did not open on this runner")
        }
        let shown = Locked("")
        let fake = FakeMoonlightHost(identity: hostIdentity, tlsIdentity: tls, client: client) { shown.get() }
        try fake.start()
        defer { fake.stop() }
        let suite = "dish.test.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = makeManager(defaults: defaults, client: client, shown: shown)
        let conn = try await stream(manager, to: fake)
        let rig = Rig(manager: manager, conn: conn)
        // The host asks for the gyro first, so the pad's motion flows for the run.
        fake.control.sendEvent(FakeMoonlightControlHost.motionRequestEvent(controller: 0, rateHz: 100, type: MoonlightMotionType.gyro))
        let asked = await eventually { conn.link.motionWanted("pad") }
        XCTAssertTrue(asked, "the host's motion request reached the link")
        let run = try await measure(rig, control: fake.control)
        // The session ends here, its clock with it, so no tick lands in the next run's count.
        manager.applyDesired([:])
        await manager.awaitQuiet()
        return run
    }

    /// The pad's feed routed to the host's link, and the host's feedback
    /// routed back to the pad's actuators, as the app wires them.
    @MainActor
    private struct Rig {
        let actuators = RecordingActuators()
        let feedback: PadFeedback
        let router: MoonlightFeedbackRouter
        let snapshot: RoutingSnapshot
        let processor = GamepadInputProcessor()
        let routing = InputRouting()

        init(manager: MoonlightConnectionManager, conn: MoonlightConnection) {
            feedback = PadFeedback(actuators: actuators, queue: ThreadRole.feedback.queue(label: "test.feedback", qos: .userInteractive))
            router = MoonlightFeedbackRouter(feedback: feedback)
            router.wire(manager.connections)
            snapshot = RoutingSnapshot(bySlot: ["pad": Route(
                sink: MoonlightPadSink(link: conn.link, slotId: "pad"),
                slot: 0,
                flags: ForwardingFlags()
            )])
            router.route(snapshot, global: ForwardingFlags())
            routing.publish(snapshot, to: processor)
        }
    }

    /// The counted stretch: the pad and the host busy on their own threads
    /// while the main actor republishes, then everything they left drained.
    private static func measure(_ rig: Rig, control: FakeMoonlightControlHost) async throws -> LockLawMoonlightRun {
        resetLockStats()
        let group = DispatchGroup()
        let finished = AtomicBool(false)
        startInputProducer(rig.processor.feed(for: "pad"), group: group)
        startHostEvents(control, group: group)
        group.notify(queue: .global(), execute: markFinished(finished))
        var tick = 0
        let giveUp = Date().addingTimeInterval(MoonlightRun.limitSeconds)
        while tick < MoonlightRun.mainTicks || !finished.get(), Date() < giveUp {
            rig.routing.republish(to: rig.processor)
            rig.router.route(rig.snapshot, global: ForwardingFlags())
            try await Task.sleep(nanoseconds: MoonlightRun.mainTickNs)
            tick += 1
        }
        XCTAssertTrue(finished.get(), "the producers finished")
        try await Task.sleep(nanoseconds: MoonlightRun.settleNs)
        drain(rig.feedback)
        let stats = lockStatsSnapshot()
        let seen = control.snapshot()
        let actuations = rig.actuators.actuations
        return LockLawMoonlightRun(
            snapshot: stats,
            frames: seen.frames.count,
            motions: seen.motions,
            rumbles: actuations.filter { if case .rumble = $0 { true } else { false } }.count,
            lamps: actuations.filter { if case .lightbar = $0 { true } else { false } }.count
        )
    }

    /// Marks the producers finished, made outside the main actor: dispatch
    /// runs it on a global queue, where an isolated closure would trap.
    private nonisolated static func markFinished(_ finished: AtomicBool) -> @Sendable () -> Void {
        { finished.set(true) }
    }

    private static func makeManager(
        defaults: UserDefaults,
        client: MoonlightIdentityStore,
        shown: Locked<String>
    ) -> MoonlightConnectionManager {
        let manager = MoonlightConnectionManager(
            store: MoonlightHostStore(defaults: defaults),
            gateway: MoonlightGateway(identity: client, pins: CertPins(file: nil)),
            identity: client,
            edges: LiveMoonlightSessionEdges(),
            discover: { [] }
        )
        manager.onEvent = { event in
            if case let .pairingPinReady(_, pin) = event { shown.set(pin) }
        }
        return manager
    }

    /// The pairing, the binding and the session, as the app would bring them up.
    private static func stream(_ manager: MoonlightConnectionManager, to fake: FakeMoonlightHost) async throws -> MoonlightConnection {
        let host = fake.host
        manager.store.put(RememberedMoonlightHost(host: host, paired: false))
        manager.publishRemembered()
        let paired = await manager.pairHost(host)
        XCTAssertTrue(paired, "the five phases against the fake host")
        let xbox = MoonlightAnnouncedPad(type: MoonlightControllerType.xbox, capabilities: 0x03, supportedButtons: 0xF7FF)
        manager.applyDesired([host.id: [MoonlightPadRequest(slotId: "pad", announced: xbox)]])
        await manager.awaitQuiet()
        let conn = try XCTUnwrap(manager.get(host.id))
        let streaming = await eventually { conn.isStreaming }
        XCTAssertTrue(streaming, "the session came up: \(conn.phase)")
        return conn
    }

    private static func drain(_ feedback: PadFeedback) {
        feedback.queue.sync {}
    }

    private static func eventually(_ predicate: @escaping @MainActor () -> Bool) async -> Bool {
        for _ in 0 ..< 500 where !predicate() {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return predicate()
    }

    /// One input-queue event as GameController delivers them: a report, and
    /// on every fourth a motion sample, on every eighth a touch.
    private static func startInputProducer(_ feed: PadFeed, group: DispatchGroup) {
        let queue = ThreadRole.input.queue(label: "test.input", qos: .userInteractive)
        group.enter()
        startThread {
            for frame in 0 ..< MoonlightRun.frames {
                queue.async { publishFrame(frame, on: feed) }
                Thread.sleep(forTimeInterval: MoonlightRun.frameSeconds)
            }
            queue.async { group.leave() }
        }
    }

    private nonisolated static func publishFrame(_ frame: Int, on feed: PadFeed) {
        feed.publishIfChanged(GamepadReport(rx: Int16(truncatingIfNeeded: frame)))
        if frame % 4 == 0 {
            feed.publishMotion(MotionSample(gyroX: 10, gyroY: 0, gyroZ: 0, accelX: 0, accelY: 0, accelZ: 8192))
        }
        if frame % 8 == 0 {
            let finger = TouchpadFinger(active: true, id: 1, x: 1000, y: -1000)
            feed.publishTouchpad(TouchpadSample(finger0: finger, finger1: .none, buttonPressed: false))
        }
    }

    /// The host's rumble on a thread of its own, and its light on every tenth.
    private static func startHostEvents(_ control: FakeMoonlightControlHost, group: DispatchGroup) {
        group.enter()
        startThread {
            for tick in 0 ..< MoonlightRun.rumbleTicks {
                control.sendEvent(FakeMoonlightControlHost.rumbleEvent(controller: 0, low: 30000, high: 10000))
                if tick % MoonlightRun.lightbarEvery == 0 {
                    control.sendEvent(FakeMoonlightControlHost.rgbLedEvent(controller: 0, red: 0, green: 64, blue: 255))
                }
                Thread.sleep(forTimeInterval: MoonlightRun.rumbleSeconds)
            }
            group.leave()
        }
    }
}

/// The run's shape: long enough for many main-actor ticks, keepalives and
/// host events to land while the pad publishes.
private enum MoonlightRun {
    static let limitSeconds: TimeInterval = 60
    static let frames = 2000
    static let frameSeconds = 0.001
    static let mainTicks = 25
    static let mainTickNs: UInt64 = 100_000_000
    static let rumbleTicks = 220
    static let rumbleSeconds = 0.01
    static let lightbarEvery = 10
    static let settleNs: UInt64 = 300_000_000
}

private func startThread(_ body: @escaping @Sendable () -> Void) {
    let thread = Thread(block: body)
    thread.qualityOfService = .userInteractive
    thread.start()
}
#endif
