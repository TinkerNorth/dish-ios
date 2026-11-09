// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// Feedback in one hop: the receive loop resolves each command against the
/// routes its handlers captured and posts it to the pad's record, and the
/// feedback queue applies the newest of each kind. The decisions follow the
/// switches, a burst drains once, and the main thread is not on the way.
@MainActor
final class PadFeedbackTests: XCTestCase {

    private enum Kind: CaseIterable {
        case rumble, lightbar, triggerEffects, playerLeds
    }

    private static let block = [UInt8](repeating: 0, count: 11)

    /// Pads on two satellites; one with its rumble off, one with all its
    /// feedback switches off.
    private var snapshot: RoutingSnapshot {
        let quiet = ForwardingFlags(rumble: false)
        let dark = ForwardingFlags(rumble: false, lightbar: false, triggerEffects: false, playerLeds: false)
        return RoutingSnapshot(bySatellitePad: [
            SatellitePadKey(connectionId: "sat-a", controllerIndex: 0): BoundSlotRoute(slotId: "a0", flags: ForwardingFlags()),
            SatellitePadKey(connectionId: "sat-a", controllerIndex: 1): BoundSlotRoute(slotId: "a1", flags: quiet),
            SatellitePadKey(connectionId: "sat-a", controllerIndex: 2): BoundSlotRoute(slotId: "a2", flags: dark),
            SatellitePadKey(connectionId: "sat-b", controllerIndex: 0): BoundSlotRoute(slotId: "b0", flags: ForwardingFlags())
        ])
    }

    /// The slot bound to the connection's index, behind its own switch for
    /// each kind and, for the light bar, the global switch too.
    private func expectedSlot(_ kind: Kind, connection: String, index: UInt8, global: ForwardingFlags) -> String? {
        let key = SatellitePadKey(connectionId: connection, controllerIndex: Int(index))
        guard let bound = snapshot.bySatellitePad[key] else { return nil }
        let allowed = switch kind {
        case .rumble: bound.flags.rumble
        case .lightbar: global.lightbar && bound.flags.lightbar
        case .triggerEffects: bound.flags.triggerEffects
        case .playerLeds: bound.flags.playerLeds
        }
        return allowed ? bound.slotId : nil
    }

    func testEveryTargetIsDecidedByTheBoundPadsSwitches() {
        for global in [ForwardingFlags(), ForwardingFlags(lightbar: false)] {
            for connection in ["sat-a", "sat-b", "sat-unknown"] {
                for index in [UInt8(0), 1, 2, 3, 9] {
                    for kind in Kind.allCases {
                        let actuated = deliver(kind, connection: connection, index: index, global: global)
                        let expected = expectedSlot(kind, connection: connection, index: index, global: global)
                        XCTAssertEqual(
                            actuated,
                            expected.map { [$0] } ?? [],
                            "\(kind) on \(connection)[\(index)], light bar \(global.lightbar)"
                        )
                    }
                }
            }
        }
    }

    /// One command through the routes a connection's handlers would capture,
    /// and the slots the queue actuated for it.
    private func deliver(_ kind: Kind, connection: String, index: UInt8, global: ForwardingFlags) -> [String] {
        let recorder = RecordingActuators()
        let feedback = PadFeedback(actuators: recorder, queue: DispatchSerialQueue(label: "test.feedback"))
        let routes = FeedbackRoutes(connectionId: connection, snapshot: snapshot, global: global, feedback: feedback)
        switch kind {
        case .rumble: routes.rumble(controllerIndex: index, strong: 100, weak: 200, durationMs: 300)
        case .lightbar: routes.lightbar(controllerIndex: index, red: 1, green: 2, blue: 3)
        case .triggerEffects: routes.triggerEffects(controllerIndex: index, left: Self.block, right: Self.block)
        case .playerLeds: routes.playerLeds(controllerIndex: index, player: 2)
        }
        feedback.queue.sync {}
        return recorder.actuations.map(slotId)
    }

    private func slotId(_ actuation: RecordingActuators.Actuation) -> String {
        switch actuation {
        case let .rumble(slotId, _, _, _), let .lightbar(slotId, _, _, _), let .triggerEffects(slotId, _, _), let .playerLeds(slotId, _):
            slotId
        }
    }

    // MARK: - Coalescing

    func testABurstWhileTheQueueIsBusyAppliesItsLastValueOnce() {
        let recorder = RecordingActuators()
        let feedback = PadFeedback(actuators: recorder, queue: DispatchSerialQueue(label: "test.feedback"))
        let pad = feedback.pad(for: "pad")
        let release = DispatchSemaphore(value: 0)
        feedback.queue.async { release.wait() }
        for step in 1 ... 50 {
            pad.post(rumbleStrong: UInt16(step), weak: 7, durationMs: 300)
            pad.post(lightbarRed: UInt8(step), green: 0, blue: 0)
            pad.post(player: step % 4 + 1)
            pad.post(triggerEffectsLeft: [UInt8(step)] + Self.block.dropFirst(), right: Self.block)
        }
        release.signal()
        feedback.queue.sync {}
        XCTAssertEqual(recorder.actuations, [
            .rumble("pad", strong: 50, weak: 7, durationMs: 300),
            .lightbar("pad", red: 50, green: 0, blue: 0),
            .playerLeds("pad", player: 3),
            .triggerEffects("pad", left: [50] + Self.block.dropFirst(), right: Self.block)
        ])
    }

    func testAPostAfterADrainIsAppliedByTheNextOne() {
        let recorder = RecordingActuators()
        let feedback = PadFeedback(actuators: recorder, queue: DispatchSerialQueue(label: "test.feedback"))
        let pad = feedback.pad(for: "pad")
        pad.post(rumbleStrong: 1, weak: 0, durationMs: 100)
        feedback.queue.sync {}
        pad.post(rumbleStrong: 2, weak: 0, durationMs: 100)
        feedback.queue.sync {}
        XCTAssertEqual(recorder.actuations, [
            .rumble("pad", strong: 1, weak: 0, durationMs: 100),
            .rumble("pad", strong: 2, weak: 0, durationMs: 100)
        ])
    }

    func testEachSlotKeepsOneRecord() {
        let feedback = PadFeedback(actuators: RecordingActuators(), queue: DispatchSerialQueue(label: "test.feedback"))
        XCTAssertTrue(feedback.pad(for: "pad") === feedback.pad(for: "pad"))
        XCTAssertFalse(feedback.pad(for: "pad") === feedback.pad(for: "other"))
    }

    /// The main thread waits on the actuator's signal the whole time: if the
    /// rumble needed it, the wait would time out.
    func testARumblePostedFromAnotherThreadReachesThePadWhileTheMainThreadWaits() {
        let arrived = DispatchSemaphore(value: 0)
        let actuators = SignallingActuators(arrived: arrived)
        let feedback = PadFeedback(actuators: actuators, queue: DispatchSerialQueue(label: "test.feedback"))
        let routes = FeedbackRoutes(
            connectionId: "sat",
            snapshot: RoutingSnapshot(bySatellitePad: [
                SatellitePadKey(connectionId: "sat", controllerIndex: 0): BoundSlotRoute(slotId: "pad", flags: ForwardingFlags())
            ]),
            global: ForwardingFlags(),
            feedback: feedback
        )
        Thread { routes.rumble(controllerIndex: 0, strong: 30000, weak: 10000, durationMs: 500) }.start()
        XCTAssertEqual(arrived.wait(timeout: .now() + 5), .success, "the rumble reached the pad without the main thread")
        XCTAssertEqual(actuators.onMain.get(), [false])
    }

    /// The return-path controller wires each connection in the pool with
    /// routes of its own, again on every routing change.
    func testTheRouterHandsEachConnectionItsRoutesOnEveryChange() {
        let feedback = PadFeedback(actuators: RecordingActuators(), queue: DispatchSerialQueue(label: "test.feedback"))
        let router = ReturnPathRouter(feedback: feedback)
        let target = RecordingRouteTarget()
        router.wire(["sat-a": target])
        router.route(snapshot, global: ForwardingFlags())
        XCTAssertEqual(target.installs.count, 2, "one on wiring, one on the routing change")
        XCTAssertTrue(target.installs.last?.route(0)?.pad === feedback.pad(for: "a0"))
        XCTAssertNil(target.installs.last?.route(3), "no pad holds index 3")
    }
}

/// Actuators that signal when a rumble arrives and note the thread it ran on.
private final class SignallingActuators: FeedbackActuators {
    let arrived: DispatchSemaphore
    let onMain = Locked<[Bool]>([])

    init(arrived: DispatchSemaphore) {
        self.arrived = arrived
    }

    func rumble(_: String, strong _: UInt16, weak _: UInt16, durationMs _: UInt16) {
        let main = Thread.isMainThread
        onMain.mutate { $0.append(main) }
        arrived.signal()
    }

    func lightbar(_: String, red _: UInt8, green _: UInt8, blue _: UInt8) {}
    func triggerEffects(_: String, left _: [UInt8], right _: [UInt8]) {}
    func playerLeds(_: String, player _: Int) {}
}

/// A connection that keeps every set of routes it was handed.
@MainActor
private final class RecordingRouteTarget: FeedbackRouteTarget {
    private(set) var installs: [FeedbackRoutes] = []

    func setFeedbackRoutes(_ routes: FeedbackRoutes) {
        installs.append(routes)
    }
}
