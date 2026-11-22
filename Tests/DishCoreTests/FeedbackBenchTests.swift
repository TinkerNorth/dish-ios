// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// The bench as the support contract's "The bench" fixes it: a test is
/// offered only where the pad's path reaches what it drives, a motor runs
/// at 48000 for 400 ms, a cycle steps every 400 ms, the triggers hold their
/// resistance for two seconds, a state surface goes back to what the game
/// last set, and an answer keeps the time its test ended.
final class FeedbackBenchTests: XCTestCase {

    private static let everything: BenchReach = [
        .weakMotor, .strongMotor, .leftTriggerMotor, .rightTriggerMotor, .lightbar, .playerLeds, .adaptiveTriggers, .sticks
    ]

    private func offered(_ reach: BenchReach) -> [BenchTest] {
        BenchItem.allCases.flatMap { benchTests($0, reach: reach) }
    }

    // MARK: - The names

    func testEveryTestCarriesTheContractsName() {
        XCTAssertEqual(BenchTest.allCases.map(\.rawValue), [
            "rumble.weak", "rumble.strong", "rumble.both",
            "triggerRumble.left", "triggerRumble.right", "triggerRumble.both",
            "lightbar.cycle", "playerLeds.cycle", "trigger.pulse",
            "stick.drift", "stick.range"
        ])
    }

    func testEachTestSitsInTheItemItTests() {
        XCTAssertEqual(BenchTest.allCases.map(\.item), [
            .rumble, .rumble, .rumble,
            .triggerRumble, .triggerRumble, .triggerRumble,
            .lightbar, .playerLeds, .adaptiveTriggers,
            .sticks, .sticks
        ])
    }

    func testOnlyTheStickTestsAreTheStickBenchs() {
        XCTAssertEqual(BenchTest.stickDrift.stickKind, .drift)
        XCTAssertEqual(BenchTest.stickRange.stickKind, .range)
        let driving = BenchTest.allCases.filter { $0.item != .sticks }
        XCTAssertEqual(driving.compactMap(\.stickKind), [])
    }

    // MARK: - Offered only where it can land

    func testAPathThatReachesEverythingOffersEveryTestInThePagesOrder() {
        XCTAssertEqual(offered(Self.everything), BenchTest.allCases)
    }

    func testAPathThatReachesNothingOffersNoTest() {
        XCTAssertEqual(offered([]), [])
    }

    func testBothMotorsOfferEachMotorAloneAndBothTogether() {
        XCTAssertEqual(benchTests(.rumble, reach: [.weakMotor, .strongMotor]), [.rumbleWeak, .rumbleStrong, .rumbleBoth])
    }

    func testOneMotorOffersThatMotorAlone() {
        XCTAssertEqual(benchTests(.rumble, reach: [.weakMotor]), [.rumbleWeak])
        XCTAssertEqual(benchTests(.rumble, reach: [.strongMotor]), [.rumbleStrong])
    }

    func testThePhonesOneActuatorOffersOneBuzzForBothMotors() {
        XCTAssertEqual(benchTests(.rumble, reach: [.oneActuator]), [.rumbleBoth], "the phone plays the stronger motor, so weak and strong would be one buzz")
        XCTAssertEqual(offered([.oneActuator]), [.rumbleBoth])
    }

    func testTheTriggerMotorsAreOfferedOnlyWhereThePathReachesThem() {
        XCTAssertEqual(benchTests(.triggerRumble, reach: [.leftTriggerMotor, .rightTriggerMotor]), [
            .triggerRumbleLeft, .triggerRumbleRight, .triggerRumbleBoth
        ])
        XCTAssertEqual(benchTests(.triggerRumble, reach: [.rightTriggerMotor]), [.triggerRumbleRight])
        XCTAssertEqual(benchTests(.triggerRumble, reach: [.weakMotor, .strongMotor]), [], "the body's motors are not the triggers'")
    }

    func testEachStateSurfaceAndTheSticksAreOfferedOnlyWhereCarried() {
        XCTAssertEqual(offered([.lightbar]), [.lightbarCycle])
        XCTAssertEqual(offered([.playerLeds]), [.playerLedsCycle])
        XCTAssertEqual(offered([.adaptiveTriggers]), [.triggerPulse])
        XCTAssertEqual(offered([.sticks]), [.stickDrift, .stickRange])
    }

    func testATestIsOfferedExactlyWhereItsItemListsIt() {
        XCTAssertTrue(benchOffers(.rumbleWeak, reach: [.weakMotor]))
        XCTAssertFalse(benchOffers(.rumbleBoth, reach: [.weakMotor]))
        XCTAssertFalse(benchOffers(.lightbarCycle, reach: [.playerLeds]))
        XCTAssertTrue(benchOffers(.stickRange, reach: [.sticks]))
    }

    // MARK: - What each test writes, and when

    func testEachBuzzRunsTheNamedMotorAt48000For400Ms() throws {
        let buzzes: [(BenchTest, BenchWrite)] = [
            (.rumbleWeak, .rumble(strong: 0, weak: 48000, durationMs: 400)),
            (.rumbleStrong, .rumble(strong: 48000, weak: 0, durationMs: 400)),
            (.rumbleBoth, .rumble(strong: 48000, weak: 48000, durationMs: 400)),
            (.triggerRumbleLeft, .triggerRumble(left: 48000, right: 0, durationMs: 400)),
            (.triggerRumbleRight, .triggerRumble(left: 0, right: 48000, durationMs: 400)),
            (.triggerRumbleBoth, .triggerRumble(left: 48000, right: 48000, durationMs: 400))
        ]
        for (test, write) in buzzes {
            let plan = try XCTUnwrap(benchPlan(test), "\(test)")
            XCTAssertEqual(plan.steps, [BenchStep(atMs: 0, write: write)], "\(test)")
            XCTAssertEqual(plan.durationMs, 400, "\(test)")
        }
    }

    func testTheLightBarCyclesRedGreenThenBlue400MsEach() throws {
        let plan = try XCTUnwrap(benchPlan(.lightbarCycle))
        XCTAssertEqual(plan.steps, [
            BenchStep(atMs: 0, write: .lightbar(BenchColour(red: 0xFF, green: 0, blue: 0))),
            BenchStep(atMs: 400, write: .lightbar(BenchColour(red: 0, green: 0xFF, blue: 0))),
            BenchStep(atMs: 800, write: .lightbar(BenchColour(red: 0, green: 0, blue: 0xFF)))
        ])
        XCTAssertEqual(plan.durationMs, 1200)
    }

    func testThePlayerLedsCycleTheFrameworksFourPlayers400MsEach() throws {
        let plan = try XCTUnwrap(benchPlan(.playerLedsCycle))
        XCTAssertEqual(plan.steps, [
            BenchStep(atMs: 0, write: .player(1)),
            BenchStep(atMs: 400, write: .player(2)),
            BenchStep(atMs: 800, write: .player(3)),
            BenchStep(atMs: 1200, write: .player(4))
        ])
        XCTAssertEqual(plan.durationMs, 1600)
    }

    /// Why the player cycle is by player and not the contract's masks: a
    /// framework that lights the LEDs by player index takes a mask as the
    /// count of its lit LEDs, and each of the contract's masks lights one.
    func testTheContractsSingleLedMasksWouldEachLightPlayerOne() {
        let contractMasks: [UInt8] = [0x01, 0x02, 0x04, 0x08, 0x10]
        let players = contractMasks.map { PlayerLedsCommand(controllerIndex: 0, ledMask: $0).playerNumber }
        XCTAssertEqual(players, [1, 1, 1, 1, 1])
    }

    func testThePulseHoldsBothTriggersAtFullRigidResistanceForTwoSeconds() throws {
        let rigid: [UInt8] = [0x01, 0x00, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0]
        XCTAssertEqual(FeedbackBench.rigidTriggerBlock, rigid, "DualSense mode 01, start 0, force ff in byte 2")
        let plan = try XCTUnwrap(benchPlan(.triggerPulse))
        XCTAssertEqual(plan.steps, [BenchStep(atMs: 0, write: .triggerEffects(left: rigid, right: rigid))])
        XCTAssertEqual(plan.durationMs, 2000)
    }

    func testAStickTestWritesNothing() {
        XCTAssertNil(benchPlan(.stickDrift))
        XCTAssertNil(benchPlan(.stickRange))
    }

    func testEachTestThatDrivesThePadHoldsItsOwnSurface() {
        let surfaces = BenchTest.allCases.compactMap { benchPlan($0)?.surface }
        XCTAssertEqual(surfaces, [
            .rumble, .rumble, .rumble,
            .triggerRumble, .triggerRumble, .triggerRumble,
            .lightbar, .playerLeds, .triggerEffects
        ])
    }

    // MARK: - A run on virtual time

    func testTheFirstStepIsDueTheMomentTheTestStarts() throws {
        var run = try BenchRun(test: .lightbarCycle, plan: XCTUnwrap(benchPlan(.lightbarCycle)), startMs: 1000)
        XCTAssertEqual(run.due(nowMs: 1000), [.lightbar(BenchColour(red: 0xFF, green: 0, blue: 0))])
    }

    func testAStepLandsOnTheFirstTickAtOrAfterItsTimeAndOnlyOnce() throws {
        var run = try BenchRun(test: .lightbarCycle, plan: XCTUnwrap(benchPlan(.lightbarCycle)), startMs: 1000)
        XCTAssertEqual(run.due(nowMs: 1000).count, 1, "the opening red")
        XCTAssertEqual(run.due(nowMs: 1399), [])
        XCTAssertEqual(run.due(nowMs: 1420), [.lightbar(BenchColour(red: 0, green: 0xFF, blue: 0))])
        XCTAssertEqual(run.due(nowMs: 1450), [], "a step is made once")
        XCTAssertEqual(run.due(nowMs: 2000), [.lightbar(BenchColour(red: 0, green: 0, blue: 0xFF))])
    }

    func testATickLateEnoughForTwoStepsMakesBothInOrder() throws {
        var run = try BenchRun(test: .playerLedsCycle, plan: XCTUnwrap(benchPlan(.playerLedsCycle)), startMs: 0)
        XCTAssertEqual(run.due(nowMs: 850), [.player(1), .player(2), .player(3)])
    }

    func testARunEndsWhenItsTimeRunsOut() throws {
        let run = try BenchRun(test: .triggerPulse, plan: XCTUnwrap(benchPlan(.triggerPulse)), startMs: 500)
        XCTAssertEqual(run.endsAtMs, 2500)
        XCTAssertFalse(run.finished(at: 2499))
        XCTAssertTrue(run.finished(at: 2500))
    }

    // MARK: - State goes back, and the test owns its surface

    func testAHeldWordNamesEachSurfaceItHolds() {
        let held = BenchSurface.lightbar.bit | BenchSurface.triggerEffects.bit
        XCTAssertTrue(benchHolds(held, .lightbar))
        XCTAssertTrue(benchHolds(held, .triggerEffects))
        XCTAssertFalse(benchHolds(held, .playerLeds))
        XCTAssertFalse(benchHolds(0, .rumble))
        XCTAssertEqual(Set(BenchSurface.allCases.map(\.bit)).count, BenchSurface.allCases.count, "one bit per surface")
    }

    func testAStateSurfaceGoesBackToWhatTheGameLastSent() {
        XCTAssertEqual(benchRestore(gameLast: BenchColour(red: 1, green: 2, blue: 3), idle: BenchColour(red: 0, green: 0, blue: 0)), BenchColour(red: 1, green: 2, blue: 3))
    }

    func testASurfaceTheGameNeverSetGoesBackToItsIdleState() {
        XCTAssertEqual(benchRestore(gameLast: nil, idle: 2), 2)
    }

    func testABuzzSimplyStopsUnlessTheGameAskedForRumbleWhileTheTestHeldTheMotors() {
        let asked = BenchMotors(strong: 30000, weak: 1000, durationMs: 500)
        XCTAssertNil(benchRumbleAfterTest(countAtStart: 4, countNow: 4, gameLast: asked), "the game said nothing during the test")
        XCTAssertEqual(benchRumbleAfterTest(countAtStart: 4, countNow: 6, gameLast: asked), asked)
        XCTAssertNil(benchRumbleAfterTest(countAtStart: 0, countNow: 0, gameLast: nil))
    }

    // MARK: - One answer per run

    func testAnAnswerKeepsTheTimeItsTestEnded() {
        let outcome = benchOutcome(BenchQuestion(test: .rumbleWeak, endedAtMs: 1_763_585_990_000), worked: true)
        XCTAssertEqual(outcome, BenchOutcome(test: .rumbleWeak, result: .worked, atMs: 1_763_585_990_000))
        XCTAssertEqual(benchOutcome(BenchQuestion(test: .triggerPulse, endedAtMs: 7), worked: false).result, .didNotWork)
    }

    func testTheResultsCarryTheContractsWords() {
        XCTAssertEqual(BenchResult.allCases.map(\.rawValue), ["worked", "didNotWork"])
    }

    func testTheNewestTwentyAnswersAreKeptOldestFirst() {
        let answers = (1 ... 25).map { BenchOutcome(test: .rumbleBoth, result: .worked, atMs: Int64($0)) }
        let kept = answers.reduce([BenchOutcome]()) { appendingBenchOutcome($0, $1) }
        XCTAssertEqual(kept.count, 20)
        XCTAssertEqual(kept.first?.atMs, 6)
        XCTAssertEqual(kept.last?.atMs, 25)
        XCTAssertEqual(benchOutcomesKept, 20)
    }
}
