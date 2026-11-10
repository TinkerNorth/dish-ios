// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore
@testable import DishEngine

/// A host's feedback landing on the pad bound to the number it names: body
/// and trigger rumble folded per motor behind the slot's Rumble switch, the
/// lamp behind the Light bar switches, a number no pad holds reaching nothing.
/// The routes are what the main actor last built from the routing table, as
/// the app rebuilds them on every refresh.
@MainActor
final class MoonlightFeedbackRouterTests: XCTestCase {

    private let playStation = MoonlightAnnouncedPad(
        type: MoonlightControllerType.playStation,
        capabilities: 0xFF,
        supportedButtons: 0x10F7FF
    )
    private let actuators = RecordingActuators()
    private var feedback: PadFeedback!
    private var conn: MoonlightConnection!
    private var router: MoonlightFeedbackRouter!

    override func setUp() async throws {
        try await super.setUp()
        feedback = PadFeedback(actuators: actuators, queue: DispatchSerialQueue(label: "test.feedback"))
        conn = MoonlightConnection(id: "moonlight:10.0.0.5", host: MoonlightHost(name: "PC", address: "10.0.0.5"))
        _ = conn.acquirePad("ds", as: playStation)
        router = MoonlightFeedbackRouter(feedback: feedback)
        router.wire([conn.id: conn])
        route(rumble: true)
    }

    /// The slot's own switches and the global ones, as a routing refresh hands them over.
    private func route(rumble: Bool, lightbar: Bool = true, global: ForwardingFlags = ForwardingFlags()) {
        var snapshot = RoutingSnapshot()
        snapshot.bySlot["ds"] = Route(
            sink: MoonlightPadSink(link: conn.link, slotId: "ds"),
            slot: 0,
            flags: ForwardingFlags(rumble: rumble, lightbar: lightbar)
        )
        router.route(snapshot, global: global)
    }

    /// The feedback queue drained, so every post has reached the actuators.
    private func settle() {
        feedback.queue.sync {}
    }

    private var rumbles: [RecordingActuators.Actuation] {
        actuators.actuations.filter { if case .rumble = $0 { true } else { false } }
    }

    private var lamps: [RecordingActuators.Actuation] {
        actuators.actuations.filter { if case .lightbar = $0 { true } else { false } }
    }

    func testBodyAndTriggerRumbleFoldPerMotorOntoTheBoundPad() {
        conn.receive(.rumble(controller: 0, low: 1000, high: 2000))
        settle()
        XCTAssertEqual(
            rumbles,
            [.rumble("ds", strong: 1000, weak: 2000, durationMs: 1500)],
            "low frequency is the large motor, held until the next"
        )
        conn.receive(.rumbleTriggers(controller: 0, left: 3000, right: 500))
        settle()
        XCTAssertEqual(rumbles.last, .rumble("ds", strong: 3000, weak: 2000, durationMs: 1500), "per-motor maximum, never a sum")
        conn.receive(.rumble(controller: 0, low: 0, high: 0))
        settle()
        XCTAssertEqual(
            rumbles.last,
            .rumble("ds", strong: 3000, weak: 500, durationMs: 1500),
            "the triggers still hold their motors"
        )
        XCTAssertEqual(rumbles.count, 3)
    }

    func testTheSlotsRumbleSwitchOffDropsItAndOnLetsItThrough() {
        route(rumble: false)
        conn.receive(.rumble(controller: 0, low: 1000, high: 2000))
        settle()
        XCTAssertEqual(rumbles, [])
        route(rumble: true)
        conn.receive(.rumble(controller: 0, low: 1000, high: 2000))
        settle()
        XCTAssertEqual(rumbles.count, 1)
    }

    func testTheLampFollowsTheLightBarSwitchesGlobalAndTheSlotsOwn() {
        route(rumble: true, global: ForwardingFlags(lightbar: false))
        conn.receive(.rgbLed(controller: 0, red: 1, green: 2, blue: 3))
        settle()
        XCTAssertEqual(lamps, [], "the global switch is off")
        route(rumble: true, lightbar: false, global: ForwardingFlags(lightbar: true))
        conn.receive(.rgbLed(controller: 0, red: 1, green: 2, blue: 3))
        settle()
        XCTAssertEqual(lamps, [], "the slot's own switch is off")
        route(rumble: true, lightbar: true, global: ForwardingFlags(lightbar: true))
        conn.receive(.rgbLed(controller: 0, red: 1, green: 2, blue: 3))
        settle()
        XCTAssertEqual(lamps, [.lightbar("ds", red: 1, green: 2, blue: 3)])
    }

    func testANumberNoPadHoldsReachesNothing() {
        conn.receive(.rumble(controller: 3, low: 1000, high: 2000))
        conn.receive(.rumble(controller: 0x100, low: 1000, high: 2000))
        conn.receive(.rgbLed(controller: 1, red: 1, green: 2, blue: 3))
        conn.receive(.rumble(controller: 0, low: 7, high: 8))
        settle()
        XCTAssertEqual(rumbles, [.rumble("ds", strong: 7, weak: 8, durationMs: 1500)])
        XCTAssertEqual(lamps, [])
    }

    func testASlotTheRoutesDoNotNameReachesNothing() {
        router.route(RoutingSnapshot(), global: ForwardingFlags())
        conn.receive(.rumble(controller: 0, low: 7, high: 8))
        conn.receive(.rgbLed(controller: 0, red: 1, green: 2, blue: 3))
        settle()
        XCTAssertEqual(actuators.actuations, [], "a pad with no route is a pad that left")
    }

    func testAHostIsWiredOnceAndAgainAfterItLeftAndCameBack() {
        router.wire([conn.id: conn])
        conn.receive(.rumble(controller: 0, low: 1, high: 1))
        settle()
        XCTAssertEqual(rumbles.count, 1, "wired once, however often the pool is seen")
        router.wire([:])
        router.wire([conn.id: conn])
        conn.receive(.rumble(controller: 0, low: 2, high: 2))
        settle()
        XCTAssertEqual(rumbles.count, 2)
    }
}
