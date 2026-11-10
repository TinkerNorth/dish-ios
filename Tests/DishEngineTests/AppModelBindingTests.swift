// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// Binding a pad to a satellite through the model: the apply follows the
/// satellite until it carries the pad, the pad's feed gets the live client
/// as its route and its reports reach the satellite encrypted, the return
/// paths reach the pad, and an unbind, a refusal and a pad that leaves each
/// let the binding go.
@MainActor
final class AppModelBindingTests: XCTestCase {

    private var fixture: SatelliteModelFixture!

    override func setUp() async throws {
        fixture = try SatelliteModelFixture(self)
    }

    override func tearDown() async throws {
        fixture?.tearDown()
        fixture = nil
    }

    private var model: AppModel {
        fixture.model
    }

    private var feed: PadFeed {
        fixture.source.processor.feed(for: "pad")
    }

    func testBindingToALiveSatelliteAppliesOnItAndRoutesThePadsFeed() async throws {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        XCTAssertEqual(model.bindingProgress, .running(.applyingOnHost))
        let done = await fixture.waitUntil { self.model.bindingProgress == .done }
        XCTAssertTrue(done, "the satellite confirmed the pad: \(model.bindingProgress)")
        XCTAssertEqual(fixture.satellite.appliedControllers.first?["type"] as? Int, 2, "a DualSense is emulated as itself")

        feed.publish(GamepadReport(buttons: 0x0010, lt: 3))
        let frame = try XCTUnwrap(fixture.satellite.awaitFrame(opcode: FakeSatelliteOpcode.input))
        guard case let .input(ctrlIdx, _) = frame.detail else { return XCTFail("an input frame: \(frame.detail)") }
        XCTAssertEqual(ctrlIdx, 0, "the pad rides the index it holds")
        XCTAssertEqual(model.shellFacts.controllers.first?.destination, DestinationFact(name: "Den PC", health: .online))
    }

    func testBindingToASatelliteWithoutASessionReachesForItAndRidesTheSessionPut() async throws {
        fixture.prePair()
        model.bind(slotId: "pad", to: fixture.serverId)
        XCTAssertEqual(model.bindingProgress, .running(.binding))
        let done = await fixture.waitUntil { self.model.bindingProgress == .done }
        XCTAssertTrue(done, "\(model.bindingProgress)")
        let put = try XCTUnwrap(fixture.satellite.sessionPuts.first)
        XCTAssertEqual((put["controllers"] as? [[String: Any]])?.count, 1, "the descriptor rode the first PUT")
    }

    func testThePadsMotionAndTouchSendThroughTheRouteOnceBound() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        feed.publishMotion(MotionSample(gyroX: 1, gyroY: 2, gyroZ: 3, accelX: 4, accelY: 5, accelZ: 6))
        XCTAssertNotNil(fixture.satellite.awaitFrame(opcode: FakeSatelliteOpcode.motion))
    }

    func testUnbindClearsThePadsRouteAndTheSatelliteLetsItGo() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        let applied = await fixture.waitUntil { self.fixture.satellite.appliedControllers.count == 1 }
        XCTAssertTrue(applied)
        model.unbind(slotId: "pad")
        XCTAssertNil(model.shellFacts.controllers.first?.destination)
        XCTAssertNil(model.routing.table.get("pad"))
        let deleted = await fixture.waitUntil { self.fixture.satellite.appliedControllers.isEmpty }
        XCTAssertTrue(deleted, "the per-slot DELETE reached the satellite")
    }

    func testARefusedPadRollsTheBindingBackAndTheApplyFails() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.satellite.controllerApplyFailure = "noSlots"
        model.bind(slotId: "pad", to: fixture.serverId)
        let failed = await fixture.waitUntil { self.model.bindingProgress == .failed(.rejected) }
        XCTAssertTrue(failed, "\(model.bindingProgress)")
        XCTAssertEqual(model.network.hub.bindings, [:])
        XCTAssertEqual(model.lastConnectionEvent, .failure(.controllerNotApplied))
    }

    func testAPadThatLeavesLetsItsBindingGo() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        fixture.source.slots = []
        let released = await fixture.waitUntil { self.model.network.hub.bindings.isEmpty }
        XCTAssertTrue(released)
    }

    func testBindingAPadIOSDoesNotListFails() {
        model.bind(slotId: "ghost", to: fixture.serverId)
        XCTAssertEqual(model.bindingProgress, .failed(.padGone))
    }

    func testTheSatellitesRumbleReachesTheBoundPad() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        let done = await fixture.waitUntil { self.model.bindingProgress == .done }
        XCTAssertTrue(done)
        XCTAssertTrue(fixture.satellite.awaitHeartbeats(atLeast: 1), "the reply path is learned from an uplink")
        XCTAssertTrue(fixture.satellite.injectRumble(ctrlIdx: 0, strong: 30000, weak: 10000, durationMs: 250))
        let actuators = fixture.source.actuators
        let felt = await fixture.waitUntil {
            self.fixture.source.feedback.queue.sync {}
            return actuators.actuations.contains(.rumble("pad", strong: 30000, weak: 10000, durationMs: 250))
        }
        XCTAssertTrue(felt, "the rumble reached the pad bound to its index: \(actuators.actuations)")
    }

    func testAnEmulatePickReachesTheBoundDescriptor() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        let applied = await fixture.waitUntil { self.fixture.satellite.appliedControllers.count == 1 }
        XCTAssertTrue(applied)
        model.setEmulatedType(slotId: "pad", .xboxWireless)
        let retyped = await fixture.waitUntil { self.fixture.satellite.appliedControllers.first?["type"] as? Int == 0 }
        XCTAssertTrue(retyped, "the pick re-sent the pad's descriptor")
    }
}
