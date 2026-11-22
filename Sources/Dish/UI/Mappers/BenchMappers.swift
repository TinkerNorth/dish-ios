// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation

/// One test's row: what it is called, and whether it runs or can.
struct BenchTestRowState: Equatable, Identifiable {
    let id: BenchTest
    let label: String
    /// This is the test under way: the row spins.
    let running: Bool
    /// False while the pad runs any test.
    let enabled: Bool
}

/// One item the pad's path carries: its eyebrow, its tests, the stick
/// tests' line, and the note under them.
struct BenchSectionState: Equatable, Identifiable {
    let id: BenchItem
    let title: String
    let rows: [BenchTestRowState]
    /// The stick tests' countdown or last result; nil for every other item,
    /// and before the first stick test.
    let status: String?
    let footer: String
}

/// One answer kept, newest first.
struct BenchAnswerLine: Equatable, Identifiable {
    let id: Int
    let text: String
}

/// "Did it work?": the question for the test the pad ran last, once it has
/// ended, the two answers, and the answers so far, newest first, with the
/// hint before there is any.
struct BenchAnswersState: Equatable {
    let title: String
    let question: String?
    let worked: String
    let didNotWork: String
    let answers: [BenchAnswerLine]
    let hint: String?
}

/// The bench of a pad that is listed.
struct BenchCardState: Equatable {
    let intro: String
    /// Only the items the pad's path carries, in the bench's order.
    let sections: [BenchSectionState]
    /// The word for a path that carries nothing to test; nil while it
    /// carries something.
    let nothing: String?
    let answers: BenchAnswersState
}

enum BenchContent: Equatable {
    case pad(BenchCardState)
    /// The pad left while its page was open.
    case gone(message: String)
}

/// Diagnostics › a controller › Controller tests.
struct BenchPageState: Equatable {
    let title: String
    /// The pad's name; empty while the pad is away.
    let subtitle: String
    let content: BenchContent
}

func benchPageState(id: String, facts: BenchFacts, words: L10n = .app) -> BenchPageState {
    guard let controller = facts.controllers.first(where: { $0.id == id }) else {
        return BenchPageState(title: words.controllerTests, subtitle: "", content: .gone(message: words.controllerGone))
    }
    let reach = facts.reach[id] ?? []
    let bench = facts.bench
    let status = stickStatus(secondsLeft: bench.stickSecondsLeft[id], result: bench.stickResults[id], words: words)
    let sections = BenchItem.allCases.compactMap { item in
        benchSection(item, reach: reach, running: bench.running[id], status: status, words: words)
    }
    let card = BenchCardState(
        intro: words.benchIntro,
        sections: sections,
        nothing: sections.isEmpty ? words.nothingToTestHere : nil,
        answers: benchAnswers(id, reach: reach, bench: bench, words: words)
    )
    return BenchPageState(title: words.controllerTests, subtitle: controllerName(controller, words: words), content: .pad(card))
}

/// An item's section, or none where the path carries none of its tests.
/// While the pad runs a test, every row waits and the running one spins.
private func benchSection(
    _ item: BenchItem,
    reach: BenchReach,
    running: BenchTest?,
    status: String?,
    words: L10n
) -> BenchSectionState? {
    let tests = benchTests(item, reach: reach)
    guard !tests.isEmpty else { return nil }
    let rows = tests.map { test in
        BenchTestRowState(id: test, label: benchRowLabel(test, reach: reach, words: words), running: test == running, enabled: running == nil)
    }
    let line = item == .sticks ? status : nil
    return BenchSectionState(id: item, title: benchItemTitle(item, words: words), rows: rows, status: line, footer: benchItemNote(item, words: words))
}

func benchItemTitle(_ item: BenchItem, words: L10n = .app) -> String {
    switch item {
    case .rumble: words.carriesRumble
    case .triggerRumble: words.triggerRumble
    case .lightbar: words.lightBar
    case .playerLeds: words.playerLeds
    case .adaptiveTriggers: words.adaptiveTriggers
    case .sticks: words.stickTests
    }
}

/// What the item's tests do, under them.
func benchItemNote(_ item: BenchItem, words: L10n = .app) -> String {
    switch item {
    case .rumble: words.rumbleTestNote
    case .triggerRumble: words.triggerRumbleTestNote
    case .lightbar: words.lightbarTestNote
    case .playerLeds: words.playerLedsTestNote
    case .adaptiveTriggers: words.triggerPulseNote
    case .sticks: words.stickTestsReadRaw
    }
}

/// A test on its row: a stick test with what to do while it captures,
/// every other by its name.
func benchRowLabel(_ test: BenchTest, reach: BenchReach, words: L10n = .app) -> String {
    switch test {
    case .stickDrift: words.driftTestButton
    case .stickRange: words.rangeTestButton
    case .rumbleWeak, .rumbleStrong, .rumbleBoth, .triggerRumbleLeft, .triggerRumbleRight, .triggerRumbleBoth,
         .lightbarCycle, .playerLedsCycle, .triggerPulse: benchTestName(test, reach: reach, words: words)
    }
}

/// A test by its name, where its answer is asked and kept: the phone's one
/// actuator plays both motors as one buzz, and is named for it.
func benchTestName(_ test: BenchTest, reach: BenchReach, words: L10n = .app) -> String {
    switch test {
    case .rumbleWeak: words.weakMotor
    case .rumbleStrong: words.strongMotor
    case .rumbleBoth: reach.contains(.oneActuator) ? words.shortBuzz : words.bothMotors
    case .triggerRumbleLeft: words.leftTriggerMotor
    case .triggerRumbleRight: words.rightTriggerMotor
    case .triggerRumbleBoth: words.bothTriggerMotors
    case .lightbarCycle: words.lightbarCycle
    case .playerLedsCycle: words.playerLedCycle
    case .triggerPulse: words.triggerResistance
    case .stickDrift: words.driftTest
    case .stickRange: words.rangeTest
    }
}

/// The stick tests' line: the countdown while one captures, else the last
/// result, else nothing.
func stickStatus(secondsLeft: Int?, result: StickTestResult?, words: L10n = .app) -> String? {
    if let secondsLeft { return words.capturingSeconds(secondsLeft) }
    return result.map { stickResultText($0, words: words) }
}

/// dish-mac's inspector's figures, each a whole percent.
func stickResultText(_ result: StickTestResult, words: L10n = .app) -> String {
    guard result.samples > 0 else { return words.testSawNothing }
    switch result.kind {
    case .drift:
        return paragraph(
            words.restingDrift(stickPercent(result.driftLeft, words: words), stickPercent(result.driftRight, words: words)),
            words.suggestedDeadZone(stickPercent(result.suggestedDeadzone, words: words))
        )
    case .range:
        return paragraph(
            words.stickReach(stickPercent(result.reachLeft, words: words), stickPercent(result.reachRight, words: words)),
            words.circularityError(circularityText(result.circularityLeft, words: words), circularityText(result.circularityRight, words: words))
        )
    }
}

private func stickPercent(_ fraction: Float, words: L10n) -> String {
    words.percent(Int((fraction * 100).rounded()))
}

/// Nil when the sweep never covered enough of the circle for a verdict.
private func circularityText(_ error: Float?, words: L10n) -> String {
    error.map { stickPercent($0, words: words) } ?? words.notApplicable
}

func benchResultText(_ result: BenchResult, words: L10n = .app) -> String {
    switch result {
    case .worked: words.itWorked
    case .didNotWork: words.itDidNotWork
    }
}

func benchAnswers(_ id: String, reach: BenchReach, bench: BenchState, words: L10n = .app) -> BenchAnswersState {
    let question = bench.asking[id].map { words.didTestWork(benchTestName($0.test, reach: reach, words: words)) }
    let kept = (bench.answers[id] ?? []).reversed().enumerated().map { offset, outcome in
        BenchAnswerLine(id: offset, text: dotted(benchTestName(outcome.test, reach: reach, words: words), benchResultText(outcome.result, words: words)))
    }
    return BenchAnswersState(
        title: words.didItWork,
        question: question,
        worked: words.itWorked,
        didNotWork: words.itDidNotWork,
        answers: kept,
        hint: kept.isEmpty ? words.benchAnswersHint : nil
    )
}
