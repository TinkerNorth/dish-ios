// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// Two clocks the test moves by hand: the uptime a test's steps are timed
/// by, and the wall clock its answer is dated by.
@MainActor
final class ManualBenchClock: BenchClock {
    var uptime: Int64 = 1000
    var wall: Int64 = 1_800_000_000_000

    func uptimeMs() -> Int64 {
        uptime
    }

    func wallMs() -> Int64 {
        wall
    }
}

/// One bench over recording actuators, a manual ticker and manual clocks.
@MainActor
private struct BenchRig {
    let ticker = ManualTicker()
    let clock = ManualBenchClock()
    let actuators = RecordingActuators(idle: PadIdleState(lightbar: BenchColour(red: 9, green: 8, blue: 7), player: 0))
    let processor = GamepadInputProcessor()
    let feedback: PadFeedback
    let store: BenchStore

    init() {
        feedback = PadFeedback(actuators: actuators, queue: DispatchSerialQueue(label: "test.feedback"))
        store = BenchStore(feedback: feedback, processor: processor, ticker: ticker, clock: clock)
    }

    /// Moves the uptime to `ms` and fires one tick, then lets the queue drain.
    func tick(at ms: Int64) {
        clock.uptime = ms
        ticker.fire()
        feedback.queue.sync {}
    }

    var actuations: [RecordingActuators.Actuation] {
        feedback.queue.sync {}
        return actuators.actuations
    }
}

/// The bench's runner: one test at a time per pad, its steps on the bench's
/// tick, the state it held put back as it ends, then "Did it work?", whose
/// answer is the outcome, timed as the test ended. The ticker runs only
/// while a test does.
@MainActor
final class BenchStoreTests: XCTestCase {

    // MARK: - A test that drives the pad

    func testATestDrivesThePadOnTheTickAndPutsTheStateBackAsItEnds() {
        let rig = BenchRig()
        rig.store.start(.lightbarCycle, slotId: "pad")
        XCTAssertEqual(rig.actuations, [.lightbar("pad", red: 0xFF, green: 0, blue: 0)], "the first step lands as the test starts")
        XCTAssertEqual(rig.store.state.running, ["pad": .lightbarCycle])
        XCTAssertEqual(rig.ticker.starts, [BenchStore.tickSeconds])
        rig.tick(at: 1350)
        XCTAssertEqual(rig.actuations.count, 1, "green waits for its 400 ms")
        rig.tick(at: 1400)
        rig.tick(at: 1800)
        rig.clock.wall = 1_800_000_001_200
        rig.tick(at: 2200)
        let cycleThenBack: [RecordingActuators.Actuation] = [
            .lightbar("pad", red: 0xFF, green: 0, blue: 0),
            .lightbar("pad", red: 0, green: 0xFF, blue: 0),
            .lightbar("pad", red: 0, green: 0, blue: 0xFF),
            .lightbar("pad", red: 9, green: 8, blue: 7)
        ]
        XCTAssertEqual(rig.actuations, cycleThenBack, "the colour the pad showed before goes back")
        XCTAssertEqual(rig.store.state.running, [:])
        XCTAssertEqual(rig.store.state.asking, ["pad": BenchQuestion(test: .lightbarCycle, endedAtMs: 1_800_000_001_200)])
        XCTAssertFalse(rig.ticker.running, "nothing runs, so nothing ticks")
    }

    func testABuzzRunsItsMotorFor400MsAndAsksAsItEnds() {
        let rig = BenchRig()
        rig.store.start(.rumbleStrong, slotId: "pad")
        rig.tick(at: 1399)
        XCTAssertEqual(rig.store.state.running, ["pad": .rumbleStrong])
        rig.tick(at: 1400)
        XCTAssertEqual(rig.actuations, [.rumble("pad", strong: 48000, weak: 0, durationMs: 400)], "the buzz stops on its own")
        XCTAssertEqual(rig.store.state.asking["pad"]?.test, .rumbleStrong)
    }

    func testAPadRunsOneTestAtATimeWhileAnotherPadRunsItsOwn() {
        let rig = BenchRig()
        rig.store.start(.playerLedsCycle, slotId: "pad")
        rig.store.start(.rumbleWeak, slotId: "pad")
        rig.store.start(.triggerRumbleLeft, slotId: "other")
        XCTAssertEqual(rig.store.state.running, ["pad": .playerLedsCycle, "other": .triggerRumbleLeft])
        XCTAssertEqual(rig.actuations, [
            .playerLeds("pad", player: 1),
            .triggerRumble("other", left: 48000, right: 0, durationMs: 400)
        ])
        XCTAssertEqual(rig.ticker.starts.count, 1, "one tick serves every test under way")
    }

    // MARK: - One answer per run

    func testANewTestTakesTheQuestionThePadStillWaitedOn() {
        let rig = BenchRig()
        rig.store.start(.rumbleWeak, slotId: "pad")
        rig.tick(at: 1400)
        XCTAssertNotNil(rig.store.state.asking["pad"])
        rig.store.start(.rumbleBoth, slotId: "pad")
        XCTAssertNil(rig.store.state.asking["pad"], "a run asks once, after it ends")
        rig.tick(at: 1800)
        XCTAssertEqual(rig.store.state.asking["pad"]?.test, .rumbleBoth)
    }

    func testAnAnswerIsTheOutcomeTimedAsTheTestEnded() {
        let rig = BenchRig()
        rig.store.start(.triggerPulse, slotId: "pad")
        rig.clock.wall = 5000
        rig.tick(at: 3000)
        rig.clock.wall = 9000
        rig.store.answer(slotId: "pad", worked: false)
        XCTAssertEqual(rig.store.state.answers, ["pad": [BenchOutcome(test: .triggerPulse, result: .didNotWork, atMs: 5000)]])
        XCTAssertNil(rig.store.state.asking["pad"])
    }

    func testAnAnswerWithNoQuestionWaitingChangesNothing() {
        let rig = BenchRig()
        rig.store.answer(slotId: "pad", worked: true)
        XCTAssertEqual(rig.store.state, BenchState())
    }

    func testEachPadKeepsItsNewestTwentyAnswers() {
        let rig = BenchRig()
        for run in 1 ... 22 {
            rig.store.start(.rumbleWeak, slotId: "pad")
            rig.clock.wall = Int64(run)
            rig.tick(at: rig.clock.uptime + 400)
            rig.store.answer(slotId: "pad", worked: true)
        }
        XCTAssertEqual(rig.store.state.answers["pad"]?.map(\.atMs), Array(3 ... 22))
    }

    // MARK: - The stick tests

    func testADriftTestSamplesTheRawSticksUntilItsCaptureEndsAndAsks() {
        let rig = BenchRig()
        rig.processor.feed(for: "pad").publishIfChanged(GamepadReport(lx: 1966, ly: 2621, rx: 0, ry: -6554))
        rig.store.start(.stickDrift, slotId: "pad")
        XCTAssertEqual(rig.store.state.running, ["pad": .stickDrift])
        XCTAssertEqual(rig.store.state.stickSecondsLeft, ["pad": 4])
        for step in 1 ... 59 {
            rig.tick(at: 1000 + Int64(step) * 50)
        }
        XCTAssertEqual(rig.store.state.stickSecondsLeft, ["pad": 1])
        rig.tick(at: 4000)
        let result = rig.store.state.stickResults["pad"]
        XCTAssertEqual(result?.kind, .drift)
        XCTAssertEqual(result?.samples, 60)
        XCTAssertEqual(result?.driftLeft ?? 0, 0.1, accuracy: 0.001, "the raw sticks, before the dead zones")
        XCTAssertEqual(result?.driftRight ?? 0, 0.2, accuracy: 0.001)
        XCTAssertEqual(result?.suggestedDeadzone ?? 0, 0.30, accuracy: 0.0001)
        XCTAssertEqual(rig.store.state.stickSecondsLeft, [:])
        XCTAssertEqual(rig.store.state.asking["pad"]?.test, .stickDrift)
        XCTAssertEqual(rig.actuations, [], "a stick test writes nothing")
    }

    func testARangeTestOfAPadThatSentNothingSawNothing() {
        let rig = BenchRig()
        rig.store.start(.stickRange, slotId: "pad")
        rig.tick(at: 9000)
        XCTAssertEqual(rig.store.state.stickResults["pad"]?.kind, .range)
        XCTAssertEqual(rig.store.state.stickResults["pad"]?.samples, 0)
        XCTAssertEqual(rig.store.state.asking["pad"]?.test, .stickRange)
    }
}
