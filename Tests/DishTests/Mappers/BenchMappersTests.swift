// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import XCTest
@testable import Dish

/// A controller's bench: only the items its path carries, in the bench's
/// order, each test on its row; one test at a time; the stick tests' line;
/// "Did it work?" once a test ends, and the answers newest first.
final class BenchMappersTests: XCTestCase {

    private static let dualSense = ControllerFact(id: "ds", name: "DualSense", link: .usbC, batteryPercent: 84, destination: nil)
    private static let xbox = ControllerFact(id: "xbox", name: "Xbox Wireless Controller", link: .bluetooth, batteryPercent: 60, destination: nil)
    private static let onScreen = ControllerFact(id: onScreenSlotId, name: "", link: .onScreen, batteryPercent: nil, destination: nil)

    private static let dualSenseReach: BenchReach = [.strongMotor, .weakMotor, .lightbar, .playerLeds, .adaptiveTriggers, .sticks]
    private static let xboxReach: BenchReach = [.strongMotor, .weakMotor, .leftTriggerMotor, .rightTriggerMotor, .sticks]

    private func facts(_ bench: BenchState = BenchState()) -> BenchFacts {
        BenchFacts(
            controllers: [Self.dualSense, Self.xbox, Self.onScreen],
            reach: [Self.dualSense.id: Self.dualSenseReach, Self.xbox.id: Self.xboxReach, onScreenSlotId: [.oneActuator]],
            bench: bench
        )
    }

    private func card(_ id: String, _ bench: BenchState = BenchState()) throws -> BenchCardState {
        guard case let .pad(card) = benchPageState(id: id, facts: facts(bench)).content else {
            throw XCTSkip("the pad is listed, so its bench is drawn")
        }
        return card
    }

    // MARK: - Offered only where it can land

    func testADualSensesBenchCarriesEachItemItsPathReachesInTheBenchsOrder() throws {
        let card = try card(Self.dualSense.id)
        XCTAssertEqual(card.sections.map(\.id), [.rumble, .lightbar, .playerLeds, .adaptiveTriggers, .sticks])
        XCTAssertEqual(card.sections.map(\.title), ["Rumble", "Light bar", "Player LEDs", "Adaptive triggers", "Stick tests"])
        XCTAssertEqual(card.sections.map { $0.rows.map(\.label) }, [
            ["Weak motor", "Strong motor", "Both motors"],
            ["Light bar cycle"],
            ["Player LED cycle"],
            ["Trigger resistance"],
            ["Drift test (hands off the sticks)", "Range test (sweep full circles)"]
        ])
        XCTAssertNil(card.nothing)
    }

    func testAnItemThePathCannotCarryIsAbsentFromThePage() throws {
        let card = try card(Self.xbox.id)
        XCTAssertEqual(card.sections.map(\.id), [.rumble, .triggerRumble, .sticks], "no light bar, LEDs or adaptive triggers")
        XCTAssertEqual(card.sections[1].rows.map(\.label), ["Left trigger motor", "Right trigger motor", "Both trigger motors"])
    }

    func testThePhonesOneActuatorIsOneShortBuzz() throws {
        let card = try card(onScreenSlotId)
        XCTAssertEqual(card.sections.map(\.id), [.rumble])
        XCTAssertEqual(card.sections.first?.rows.map(\.id), [.rumbleBoth])
        XCTAssertEqual(card.sections.first?.rows.map(\.label), ["Short buzz"])
    }

    func testAPathThatCarriesNothingSaysSo() throws {
        let facts = BenchFacts(controllers: [Self.xbox], reach: [:])
        guard case let .pad(card) = benchPageState(id: Self.xbox.id, facts: facts).content else { return XCTFail("the pad is listed") }
        XCTAssertEqual(card.sections, [])
        XCTAssertEqual(card.nothing, "Nothing on this controller’s path can be tested from here.")
    }

    func testEachItemSaysWhatItsTestsDo() throws {
        let card = try card(Self.dualSense.id)
        XCTAssertEqual(card.intro, "Each test drives the controller from here alone, with no PC in the loop.")
        XCTAssertEqual(card.sections.map(\.footer), [
            "A short buzz straight to the controller, whatever its rumble switch says.",
            "Red, green, then blue, then back to what the game set.",
            "Players one to four, then back to what the game set.",
            "Both triggers stiffen for two seconds, then go back to what the game set.",
            "The tests read the sticks as the controller sends them, before the dead zones."
        ])
        XCTAssertEqual(benchItemNote(.triggerRumble), "A short buzz in the triggers’ own motors, whatever the controller’s rumble switch says.")
        XCTAssertEqual(benchItemTitle(.triggerRumble), "Trigger rumble")
    }

    // MARK: - One test at a time

    func testWithNothingRunningEveryRowCanRun() throws {
        let rows = try card(Self.dualSense.id).sections.flatMap(\.rows)
        XCTAssertEqual(rows.map(\.enabled), Array(repeating: true, count: rows.count))
        XCTAssertEqual(rows.map(\.running), Array(repeating: false, count: rows.count))
    }

    func testWhileATestRunsEveryRowWaitsAndItsOwnSpins() throws {
        var bench = BenchState()
        bench.running[Self.dualSense.id] = .lightbarCycle
        let rows = try card(Self.dualSense.id, bench).sections.flatMap(\.rows)
        XCTAssertEqual(rows.filter(\.running).map(\.id), [.lightbarCycle])
        XCTAssertEqual(rows.map(\.enabled), Array(repeating: false, count: rows.count))
        XCTAssertEqual(try card(Self.xbox.id, bench).sections.flatMap(\.rows).map(\.enabled).contains(false), false, "another pad's bench is free")
    }

    // MARK: - The stick tests' line

    func testTheStickLineIsEmptyBeforeAnyStickTest() throws {
        XCTAssertNil(try card(Self.dualSense.id).sections.last?.status)
        XCTAssertNil(try card(Self.dualSense.id).sections.first?.status, "only the sticks have a line")
    }

    func testTheStickLineCountsDownWhileATestCaptures() throws {
        var bench = BenchState()
        bench.running[Self.dualSense.id] = .stickRange
        bench.stickSecondsLeft[Self.dualSense.id] = 7
        XCTAssertEqual(try card(Self.dualSense.id, bench).sections.last?.status, "Capturing… 7 s")
    }

    func testADriftResultReadsBothSticksAndTheSuggestedDeadZoneInWholePercent() {
        var result = StickTestResult(kind: .drift, samples: 60)
        result.driftLeft = 0.1
        result.driftRight = 0.2
        result.suggestedDeadzone = 0.3
        XCTAssertEqual(stickResultText(result), "Resting drift: L 10% · R 20%. Suggested dead zone: 30%.")
    }

    func testARangeResultReadsEachSticksReachAndRoundnessOrNoneWhereTheSweepFellShort() {
        var result = StickTestResult(kind: .range, samples: 160)
        result.reachLeft = 1
        result.reachRight = 0.707
        result.circularityLeft = 0.012
        result.circularityRight = nil
        XCTAssertEqual(stickResultText(result), "Reach: L 100% · R 71%. Circularity error: L 1% · R n/a.")
    }

    func testATestThatSawNothingSaysTheControllerSentNothing() {
        XCTAssertEqual(stickResultText(StickTestResult(kind: .drift, samples: 0)), "The controller sent nothing during the test.")
    }

    func testTheLastStickResultStaysOnTheLineOnceTheTestEnds() throws {
        var bench = BenchState()
        bench.stickResults[Self.dualSense.id] = StickTestResult(kind: .range, samples: 0)
        XCTAssertEqual(try card(Self.dualSense.id, bench).sections.last?.status, "The controller sent nothing during the test.")
    }

    // MARK: - Did it work?

    func testBeforeAnyAnswerThePageSaysHowToGiveOne() throws {
        let answers = try card(Self.dualSense.id).answers
        XCTAssertEqual(answers.title, "Did it work?")
        XCTAssertNil(answers.question)
        XCTAssertEqual(answers.answers, [])
        XCTAssertEqual(answers.hint, "Run a test above, then say whether it worked. Your answers go in the support file.")
    }

    func testAnEndedTestAsksByItsName() throws {
        var bench = BenchState()
        bench.asking[Self.dualSense.id] = BenchQuestion(test: .rumbleWeak, endedAtMs: 1)
        let answers = try card(Self.dualSense.id, bench).answers
        XCTAssertEqual(answers.question, "Weak motor: did it work?")
        XCTAssertEqual(answers.worked, "It worked")
        XCTAssertEqual(answers.didNotWork, "It didn’t work")
    }

    func testTheAnswersReadNewestFirstAndTheHintGoes() throws {
        var bench = BenchState()
        bench.answers[Self.dualSense.id] = [
            BenchOutcome(test: .triggerPulse, result: .worked, atMs: 1),
            BenchOutcome(test: .stickDrift, result: .didNotWork, atMs: 2)
        ]
        let answers = try card(Self.dualSense.id, bench).answers
        XCTAssertEqual(answers.answers.map(\.text), ["Drift test · It didn’t work", "Trigger resistance · It worked"])
        XCTAssertNil(answers.hint)
    }

    func testThePhonesBuzzIsAskedAboutAsTheBuzzItWas() throws {
        var bench = BenchState()
        bench.asking[onScreenSlotId] = BenchQuestion(test: .rumbleBoth, endedAtMs: 1)
        XCTAssertEqual(try card(onScreenSlotId, bench).answers.question, "Short buzz: did it work?")
        XCTAssertEqual(benchTestName(.rumbleBoth, reach: Self.dualSenseReach), "Both motors")
    }

    func testEveryTestHasANameOfItsOwn() {
        let names = BenchTest.allCases.map { benchTestName($0, reach: Self.dualSenseReach) }
        XCTAssertEqual(Set(names).count, BenchTest.allCases.count)
    }

    // MARK: - The page

    func testThePageIsTitledForTheTestsAndSubtitledByThePad() {
        let state = benchPageState(id: Self.dualSense.id, facts: facts())
        XCTAssertEqual(state.title, "Controller tests")
        XCTAssertEqual(state.subtitle, "DualSense")
        XCTAssertEqual(benchPageState(id: onScreenSlotId, facts: facts()).subtitle, "On-screen gamepad")
    }

    func testAPadThatLeftShowsItIsGone() {
        let state = benchPageState(id: "gone", facts: facts())
        XCTAssertEqual(state.subtitle, "")
        XCTAssertEqual(state.content, .gone(message: "This controller isn’t connected to your iPhone."))
    }
}
