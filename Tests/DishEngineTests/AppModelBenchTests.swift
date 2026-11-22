// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// The bench's intents and facts: every listed controller carries what its
/// path reaches, a test runs only where its path carries it and whatever the
/// pad's switches say, and the answer is kept for the support file.
@MainActor
final class AppModelBenchTests: XCTestCase {

    private let dualSense = ControllerSlot(
        id: "gc:Sony:DualSense",
        name: "DualSense Wireless Controller",
        capabilities: ControllerCapabilities(
            hasRumble: true,
            hasLightbar: true,
            hasTriggerEffects: true,
            hasPlayerLeds: true,
            motors: [.strongMotor, .weakMotor]
        ),
        family: .dualSense
    )

    private let xbox = ControllerSlot(
        id: "gc:Microsoft:Xbox",
        name: "Xbox Wireless Controller",
        capabilities: ControllerCapabilities(hasRumble: true, motors: [.strongMotor, .weakMotor, .leftTriggerMotor, .rightTriggerMotor]),
        family: .xbox
    )

    private let remote = ControllerSlot(id: "gc:Apple:Remote", name: "Siri Remote", readable: false)

    @MainActor
    private struct Rig {
        let model: AppModel
        let source: FakeControllerSource
        let ticker: ManualTicker
        let clock: ManualBenchClock

        /// The uptime moves to `ms` and the bench ticks once.
        func tick(at ms: Int64) {
            clock.uptime = ms
            ticker.fire()
            source.feedback.queue.sync {}
        }
    }

    private func rig(_ slots: [ControllerSlot], phoneHaptics: Bool = false) throws -> Rig {
        let source = FakeControllerSource(slots: slots)
        let ticker = ManualTicker()
        let clock = ManualBenchClock()
        let model = try AppModel(
            defaults: TestDefaults.fresh(self),
            controllerSource: source,
            benchTicker: ticker,
            benchClock: clock,
            phoneHaptics: phoneHaptics
        )
        return Rig(model: model, source: source, ticker: ticker, clock: clock)
    }

    // MARK: - What each controller's path reaches

    func testEveryListedControllerCarriesWhatItsPathReaches() throws {
        let rig = try rig([dualSense, xbox, remote])
        XCTAssertEqual(rig.model.benchFacts.reach, [
            dualSense.id: [.strongMotor, .weakMotor, .lightbar, .playerLeds, .adaptiveTriggers, .sticks],
            xbox.id: [.strongMotor, .weakMotor, .leftTriggerMotor, .rightTriggerMotor, .sticks],
            remote.id: [],
            onScreenSlotId: []
        ])
        XCTAssertEqual(rig.model.benchFacts.controllers.map(\.id), [dualSense.id, xbox.id, remote.id, onScreenSlotId])
    }

    func testTheOnScreenControllerReachesThePhonesHapticsWhereThePhoneHasThem() throws {
        let rig = try rig([], phoneHaptics: true)
        XCTAssertEqual(rig.model.benchFacts.reach[onScreenSlotId], [.oneActuator])
    }

    // MARK: - Offered only where it can land

    func testATestThePathCannotCarryIsNotRun() throws {
        let rig = try rig([xbox, remote])
        rig.model.runBenchTest(.lightbarCycle, slotId: xbox.id)
        rig.model.runBenchTest(.rumbleBoth, slotId: remote.id)
        rig.model.runBenchTest(.rumbleWeak, slotId: "gc:nobody")
        rig.source.feedback.queue.sync {}
        XCTAssertEqual(rig.model.benchFacts.bench.running, [:])
        XCTAssertEqual(rig.source.actuators.actuations, [])
        XCTAssertFalse(rig.ticker.running)
    }

    func testATestRunsWhateverThePadsSwitchesSay() throws {
        let rig = try rig([xbox])
        rig.model.setControllerFeature(slotId: xbox.id, .rumble, enabled: false)
        rig.model.setRumbleForwarded(false)
        rig.model.runBenchTest(.triggerRumbleRight, slotId: xbox.id)
        rig.source.feedback.queue.sync {}
        XCTAssertEqual(rig.source.actuators.actuations, [.triggerRumble(xbox.id, left: 0, right: 48000, durationMs: 400)])
        XCTAssertEqual(rig.model.benchFacts.bench.running, [xbox.id: .triggerRumbleRight])
    }

    func testTheOnScreenControllersBuzzRunsOnThePhone() throws {
        let rig = try rig([], phoneHaptics: true)
        rig.model.runBenchTest(.rumbleBoth, slotId: onScreenSlotId)
        rig.source.feedback.queue.sync {}
        XCTAssertEqual(rig.source.actuators.actuations, [.rumble(onScreenSlotId, strong: 48000, weak: 48000, durationMs: 400)])
    }

    // MARK: - One answer per run

    func testTheAnswerToAFinishedTestIsKeptAsItsOutcome() throws {
        let rig = try rig([dualSense])
        rig.model.runBenchTest(.triggerPulse, slotId: dualSense.id)
        rig.clock.wall = 1_763_585_990_000
        rig.tick(at: 3000)
        XCTAssertEqual(rig.model.benchFacts.bench.asking[dualSense.id], BenchQuestion(test: .triggerPulse, endedAtMs: 1_763_585_990_000))
        rig.model.answerBenchTest(slotId: dualSense.id, worked: true)
        XCTAssertEqual(rig.model.benchFacts.bench.answers[dualSense.id], [
            BenchOutcome(test: .triggerPulse, result: .worked, atMs: 1_763_585_990_000)
        ])
    }
}
