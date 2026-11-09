// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

#if LOCK_STATS
import CryptoKit
import Darwin
import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// The satellite path's run for `LockLawTests`: a pad publishing on the
/// input queue through its route to a live `SatelliteClient`, the client's
/// heartbeat, its receive loop opening rumble, light-bar and heartbeat-ack
/// datagrams that a loopback "satellite" seals as the real one does, the
/// feedback queue driving the actuators, and the main actor republishing
/// the routing table and reading the latency window every 100 ms.
@MainActor
struct LockLawSatelliteRun {
    let snapshot: LockStatsSnapshot
    let uplinks: UInt64
    let downlinks: UInt64
    let actuations: Int
    let latencySamples: Int

    static func run() throws -> LockLawSatelliteRun {
        let (fd, port) = try XCTUnwrap(DataPlaneTestHelpers.bindLoopbackSocket())
        defer { close(fd) }
        let client = try XCTUnwrap(DataPlaneTestHelpers.makeClient(port: port))
        defer { client.closeSocket() }
        let actuators = RecordingActuators()
        let feedback = PadFeedback(actuators: actuators, queue: ThreadRole.feedback.queue(label: "test.feedback", qos: .userInteractive))
        let snapshot = RoutingSnapshot(
            bySlot: ["pad": Route(sink: client, slot: 0, flags: ForwardingFlags())],
            bySatellitePad: [SatellitePadKey(connectionId: "sat", controllerIndex: 0): BoundSlotRoute(
                slotId: "pad",
                flags: ForwardingFlags()
            )]
        )
        client.setFeedbackRoutes(FeedbackRoutes(connectionId: "sat", snapshot: snapshot, global: ForwardingFlags(), feedback: feedback))
        let processor = GamepadInputProcessor()
        let routing = InputRouting()
        routing.publish(snapshot, to: processor)
        let feed = processor.feed(for: "pad")
        client.startReceiveLoop()
        client.startHeartbeat()
        resetLockStats()
        let group = DispatchGroup()
        let traffic = LoopbackTraffic()
        startLoopbackSatellite(fd: fd, traffic: traffic, group: group)
        startInputProducer(feed, group: group)
        let samples = tickTheMainActor(routing: routing, processor: processor, client: client, until: group)
        feedback.queue.sync {}
        return LockLawSatelliteRun(
            snapshot: lockStatsSnapshot(),
            uplinks: traffic.uplinks.current(),
            downlinks: traffic.downlinks.current(),
            actuations: actuators.actuations.count,
            latencySamples: samples
        )
    }

    private static func tickTheMainActor(
        routing: InputRouting,
        processor: GamepadInputProcessor,
        client: SatelliteClient,
        until group: DispatchGroup
    ) -> Int {
        var tick = 0
        var samples = 0
        let giveUp = Date().addingTimeInterval(SatelliteRun.limitSeconds)
        while tick < SatelliteRun.mainTicks || group.wait(timeout: .now()) == .timedOut, Date() < giveUp {
            routing.republish(to: processor)
            samples = client.latencySnapshot().samples
            RunLoop.main.run(until: Date().addingTimeInterval(SatelliteRun.mainTickSeconds))
            tick += 1
        }
        XCTAssertEqual(group.wait(timeout: .now()), .success, "the producers finished")
        return samples
    }

    private static func startInputProducer(_ feed: PadFeed, group: DispatchGroup) {
        let queue = ThreadRole.input.queue(label: "test.input", qos: .userInteractive)
        group.enter()
        startThread {
            for frame in 0 ..< SatelliteRun.frames {
                queue.async { feed.publishIfChanged(GamepadReport(rx: Int16(truncatingIfNeeded: frame))) }
                Thread.sleep(forTimeInterval: SatelliteRun.frameSeconds)
            }
            queue.async { group.leave() }
        }
    }

    /// Reads the client's uplink to learn its address, then answers with
    /// sealed rumble, light-bar and ack datagrams on rising counters.
    private static func startLoopbackSatellite(fd: Int32, traffic: LoopbackTraffic, group: DispatchGroup) {
        group.enter()
        startThread {
            defer { group.leave() }
            guard let client = DataPlaneTestHelpers.receiveSender(fd: fd) else { return }
            traffic.uplinks.increment()
            for counter in 1 ... UInt32(SatelliteRun.downlinks) {
                if DataPlaneTestHelpers.send(downlink(counter), from: fd, to: client) { traffic.downlinks.increment() }
                if DataPlaneTestHelpers.receiveSender(fd: fd) != nil { traffic.uplinks.increment() }
                Thread.sleep(forTimeInterval: SatelliteRun.downlinkSeconds)
            }
        }
    }

    private nonisolated static func downlink(_ counter: UInt32) -> Data {
        switch counter % 3 {
        case 0: DataPlaneTestHelpers.ackDatagram(counter: counter)
        case 1: DataPlaneTestHelpers.sealDownlink(
                msgType: ProtocolConstants.msgRumble,
                payload: Data([0, 0x75, 0x30, 0x27, 0x10, 0, 100]),
                counter: counter
            )
        default: DataPlaneTestHelpers.sealDownlink(msgType: ProtocolConstants.msgLightbar, payload: Data([0, 0, 64, 255]), counter: counter)
        }
    }
}

/// What crossed the loopback, counted on the satellite's thread.
private final class LoopbackTraffic: Sendable {
    let uplinks = AtomicCounter()
    let downlinks = AtomicCounter()
}

/// The run's shape: long enough for many main-actor ticks, heartbeats and
/// return commands to land while the pad publishes.
private enum SatelliteRun {
    static let limitSeconds: TimeInterval = 60
    static let frames = 2000
    static let frameSeconds = 0.001
    static let mainTicks = 25
    static let mainTickSeconds = 0.1
    static let downlinks = 150
    static let downlinkSeconds = 0.01
}

private func startThread(_ body: @escaping @Sendable () -> Void) {
    let thread = Thread(block: body)
    thread.qualityOfService = .userInteractive
    thread.start()
}
#endif
