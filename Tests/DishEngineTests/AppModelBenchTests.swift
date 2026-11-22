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

    /// The model's own bench ticker, over the bench's manual clocks.
    @MainActor
    private struct ScrollingRig {
        let model: AppModel
        let source: FakeControllerSource
        let clock: ManualBenchClock
    }

    private func scrollingRig(_ slots: [ControllerSlot]) throws -> ScrollingRig {
        let source = FakeControllerSource(slots: slots)
        let clock = ManualBenchClock()
        let model = try AppModel(defaults: TestDefaults.fresh(self), controllerSource: source, benchClock: clock)
        return ScrollingRig(model: model, source: source, clock: clock)
    }

    /// Runs the main run loop as UIKit does while a finger drags a list,
    /// until `predicate` holds or a second passes. UIKit makes its tracking
    /// mode one of the common modes as the app launches; the package's test
    /// bundle runs without an app, so the helper makes it one.
    private func scroll(until predicate: () -> Bool) {
        let tracking = CFRunLoopMode(RunLoop.Mode.tracking.rawValue as CFString)
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), tracking)
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline, !predicate() {
            RunLoop.main.run(mode: .tracking, before: Date().addingTimeInterval(0.01))
        }
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

    // MARK: - Keeping time

    func testATestsStepsAndItsEndKeepTimeWhileThePageScrolls() throws {
        let rig = try scrollingRig([dualSense])
        rig.model.runBenchTest(.lightbarCycle, slotId: dualSense.id)
        rig.clock.uptime = 1400
        let green = RecordingActuators.Actuation.lightbar(dualSense.id, red: 0, green: 0xFF, blue: 0)
        scroll { rig.source.actuators.actuations.contains(green) }
        XCTAssertTrue(rig.source.actuators.actuations.contains(green), "green lands mid-scroll")
        rig.clock.uptime = 2200
        scroll { rig.model.benchFacts.bench.asking[dualSense.id] != nil }
        XCTAssertEqual(rig.model.benchFacts.bench.running, [:], "the cycle ends mid-scroll")
        XCTAssertEqual(rig.model.benchFacts.bench.asking[dualSense.id]?.test, .lightbarCycle, "Did it work? is asked mid-scroll")
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
