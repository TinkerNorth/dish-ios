// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The Diagnostics bench, as the support contract's "The bench" fixes it: the
// tests a pad's path can carry, what each writes to the pad and when, the
// surface a test holds while it runs, what goes back on it when the test
// ends, and the person's answer. The strengths and times are dish-android's
// inspector's, so a pad feels one test on every client.

import Foundation

/// The bench's tests, by the names the support file carries.
package enum BenchTest: String, CaseIterable, Equatable, Sendable {
    case rumbleWeak = "rumble.weak"
    case rumbleStrong = "rumble.strong"
    case rumbleBoth = "rumble.both"
    case triggerRumbleLeft = "triggerRumble.left"
    case triggerRumbleRight = "triggerRumble.right"
    case triggerRumbleBoth = "triggerRumble.both"
    case lightbarCycle = "lightbar.cycle"
    case playerLedsCycle = "playerLeds.cycle"
    case triggerPulse = "trigger.pulse"
    case stickDrift = "stick.drift"
    case stickRange = "stick.range"

    /// The item the test belongs to: the section of the page it sits in.
    package var item: BenchItem {
        switch self {
        case .rumbleWeak, .rumbleStrong, .rumbleBoth: .rumble
        case .triggerRumbleLeft, .triggerRumbleRight, .triggerRumbleBoth: .triggerRumble
        case .lightbarCycle: .lightbar
        case .playerLedsCycle: .playerLeds
        case .triggerPulse: .adaptiveTriggers
        case .stickDrift, .stickRange: .sticks
        }
    }

    /// The stick bench's test this is; nil for a test that drives the pad.
    package var stickKind: StickTestKind? {
        switch self {
        case .stickDrift: .drift
        case .stickRange: .range
        case .rumbleWeak, .rumbleStrong, .rumbleBoth, .triggerRumbleLeft, .triggerRumbleRight, .triggerRumbleBoth,
             .lightbarCycle, .playerLedsCycle, .triggerPulse: nil
        }
    }
}

/// What the bench tests, in the page's order.
package enum BenchItem: CaseIterable, Equatable, Sendable {
    case rumble
    case triggerRumble
    case lightbar
    case playerLeds
    case adaptiveTriggers
    case sticks
}

/// What a pad's path reaches from this device alone, as its composed
/// capabilities say: the gate a test passes to be offered, the same one the
/// game's own writes pass.
package struct BenchReach: OptionSet, Hashable, Sendable {
    package let rawValue: UInt16

    package init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    /// The body's weak motor, the high-frequency one in the right handle.
    package static let weakMotor = BenchReach(rawValue: 1 << 0)
    /// The body's strong motor, the low-frequency one in the left handle.
    package static let strongMotor = BenchReach(rawValue: 1 << 1)
    /// One actuator that plays both motors as one: the phone's own.
    package static let oneActuator = BenchReach(rawValue: 1 << 2)
    package static let leftTriggerMotor = BenchReach(rawValue: 1 << 3)
    package static let rightTriggerMotor = BenchReach(rawValue: 1 << 4)
    package static let lightbar = BenchReach(rawValue: 1 << 5)
    package static let playerLeds = BenchReach(rawValue: 1 << 6)
    package static let adaptiveTriggers = BenchReach(rawValue: 1 << 7)
    /// The sticks' values, which the stick tests read.
    package static let sticks = BenchReach(rawValue: 1 << 8)
}

/// The tests a path offers for one item, in the page's order; none where it
/// cannot carry the item.
package func benchTests(_ item: BenchItem, reach: BenchReach) -> [BenchTest] {
    switch item {
    case .rumble: rumbleTests(reach)
    case .triggerRumble: motorPairTests(
            reach.contains(.leftTriggerMotor),
            reach.contains(.rightTriggerMotor),
            [.triggerRumbleLeft, .triggerRumbleRight, .triggerRumbleBoth]
        )
    case .lightbar: reach.contains(.lightbar) ? [.lightbarCycle] : []
    case .playerLeds: reach.contains(.playerLeds) ? [.playerLedsCycle] : []
    case .adaptiveTriggers: reach.contains(.adaptiveTriggers) ? [.triggerPulse] : []
    case .sticks: reach.contains(.sticks) ? [.stickDrift, .stickRange] : []
    }
}

/// Whether the path offers the test: its item lists it.
package func benchOffers(_ test: BenchTest, reach: BenchReach) -> Bool {
    benchTests(test.item, reach: reach).contains(test)
}

/// One actuator for both motors would play weak and strong as one buzz, so
/// it offers the one.
private func rumbleTests(_ reach: BenchReach) -> [BenchTest] {
    guard !reach.contains(.oneActuator) else { return [.rumbleBoth] }
    return motorPairTests(reach.contains(.weakMotor), reach.contains(.strongMotor), [.rumbleWeak, .rumbleStrong, .rumbleBoth])
}

/// Each motor of a pair alone where the path reaches it, then both where it
/// reaches both; `tests` names the first, the second and both.
private func motorPairTests(_ first: Bool, _ second: Bool, _ tests: [BenchTest]) -> [BenchTest] {
    let reached = [first, second, first && second]
    return zip(reached, tests).filter(\.0).map(\.1)
}

/// dish-android's inspector's strengths and times, which the contract's table
/// gives every client.
package enum FeedbackBench {
    /// A motor's strength, of 65535.
    package static let magnitude: UInt16 = 48000
    /// How long a motor runs.
    package static let buzzMs: UInt16 = 400
    /// Each step of a cycle.
    package static let cycleStepMs: Int64 = 400
    /// How long the adaptive triggers hold their resistance.
    package static let triggerHoldMs: Int64 = 2000
    /// The light bar's cycle: red, green, then blue.
    package static let lightbarColours = [
        BenchColour(red: 0xFF, green: 0, blue: 0),
        BenchColour(red: 0, green: 0xFF, blue: 0),
        BenchColour(red: 0, green: 0, blue: 0xFF)
    ]
    /// The player LEDs' cycle, as a framework that lights them by player
    /// index shows them: players one to four.
    package static let players = [1, 2, 3, 4]
    /// One trigger at full rigid resistance: DualSense effect mode 01 from
    /// the top of its travel, force ff in byte 2, the rest zero.
    package static let rigidTriggerBlock: [UInt8] = [0x01, 0x00, 0xFF] + [UInt8](repeating: 0, count: 8)
    /// One trigger with no effect: the block of a trigger the game never set.
    package static let releasedTriggerBlock = [UInt8](repeating: 0, count: 11)
}

/// A colour of the light bar.
package struct BenchColour: Hashable, Sendable {
    package let red: UInt8
    package let green: UInt8
    package let blue: UInt8

    package init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// The two body motors at one level, and how long it runs.
package struct BenchMotors: Hashable, Sendable {
    package let strong: UInt16
    package let weak: UInt16
    package let durationMs: UInt16

    package init(strong: UInt16, weak: UInt16, durationMs: UInt16) {
        self.strong = strong
        self.weak = weak
        self.durationMs = durationMs
    }
}

/// One write a test makes to the pad.
package enum BenchWrite: Equatable, Sendable {
    case rumble(strong: UInt16, weak: UInt16, durationMs: UInt16)
    case triggerRumble(left: UInt16, right: UInt16, durationMs: UInt16)
    case lightbar(BenchColour)
    case player(Int)
    case triggerEffects(left: [UInt8], right: [UInt8])
}

/// A write at its time from the test's start.
package struct BenchStep: Equatable, Sendable {
    package let atMs: Int64
    package let write: BenchWrite

    package init(atMs: Int64, write: BenchWrite) {
        self.atMs = atMs
        self.write = write
    }
}

/// What a test holds while it runs: the motors are transient, and the light
/// bar, the player LEDs and the adaptive triggers are state the game set.
package enum BenchSurface: Int, CaseIterable, Sendable {
    case rumble
    case triggerRumble
    case lightbar
    case playerLeds
    case triggerEffects

    /// The surface's bit in a word of held surfaces.
    package var bit: Int64 {
        1 << Int64(rawValue)
    }
}

/// Whether a word of held surfaces holds `surface`.
package func benchHolds(_ held: Int64, _ surface: BenchSurface) -> Bool {
    held & surface.bit != 0
}

/// A test that drives the pad: the surface it holds, its writes, and how
/// long it runs.
package struct BenchPlan: Equatable, Sendable {
    package let surface: BenchSurface
    package let steps: [BenchStep]
    package let durationMs: Int64
}

/// What a test writes and when; nil for a stick test, which only reads.
package func benchPlan(_ test: BenchTest) -> BenchPlan? {
    let full = FeedbackBench.magnitude
    let buzzMs = FeedbackBench.buzzMs
    let rigid = FeedbackBench.rigidTriggerBlock
    switch test {
    case .rumbleWeak: return buzz(.rumble(strong: 0, weak: full, durationMs: buzzMs), holding: .rumble)
    case .rumbleStrong: return buzz(.rumble(strong: full, weak: 0, durationMs: buzzMs), holding: .rumble)
    case .rumbleBoth: return buzz(.rumble(strong: full, weak: full, durationMs: buzzMs), holding: .rumble)
    case .triggerRumbleLeft: return buzz(.triggerRumble(left: full, right: 0, durationMs: buzzMs), holding: .triggerRumble)
    case .triggerRumbleRight: return buzz(.triggerRumble(left: 0, right: full, durationMs: buzzMs), holding: .triggerRumble)
    case .triggerRumbleBoth: return buzz(.triggerRumble(left: full, right: full, durationMs: buzzMs), holding: .triggerRumble)
    case .lightbarCycle: return cycle(FeedbackBench.lightbarColours.map(BenchWrite.lightbar), holding: .lightbar)
    case .playerLedsCycle: return cycle(FeedbackBench.players.map(BenchWrite.player), holding: .playerLeds)
    case .triggerPulse:
        let hold = BenchStep(atMs: 0, write: .triggerEffects(left: rigid, right: rigid))
        return BenchPlan(surface: .triggerEffects, steps: [hold], durationMs: FeedbackBench.triggerHoldMs)
    case .stickDrift, .stickRange: return nil
    }
}

private func buzz(_ write: BenchWrite, holding surface: BenchSurface) -> BenchPlan {
    BenchPlan(surface: surface, steps: [BenchStep(atMs: 0, write: write)], durationMs: Int64(FeedbackBench.buzzMs))
}

private func cycle(_ writes: [BenchWrite], holding surface: BenchSurface) -> BenchPlan {
    let steps = writes.enumerated().map { BenchStep(atMs: Int64($0.offset) * FeedbackBench.cycleStepMs, write: $0.element) }
    return BenchPlan(surface: surface, steps: steps, durationMs: Int64(writes.count) * FeedbackBench.cycleStepMs)
}

/// One test driving a pad: its plan, when it started, and how many of its
/// writes are made. The clock is passed in, so a run goes on virtual time.
package struct BenchRun: Equatable, Sendable {
    package let test: BenchTest
    package let plan: BenchPlan
    package let startMs: Int64
    private var made = 0

    package init(test: BenchTest, plan: BenchPlan, startMs: Int64) {
        self.test = test
        self.plan = plan
        self.startMs = startMs
    }

    package var endsAtMs: Int64 {
        startMs + plan.durationMs
    }

    /// The writes due by now that are not made yet, in order: a step lands
    /// on the first tick at or after its time, and once.
    package mutating func due(nowMs: Int64) -> [BenchWrite] {
        let elapsed = nowMs - startMs
        let next = plan.steps.dropFirst(made).prefix { $0.atMs <= elapsed }
        made += next.count
        return next.map(\.write)
    }

    package func finished(at nowMs: Int64) -> Bool {
        nowMs >= endsAtMs
    }
}

/// What goes back on a state surface when its test ends: the last value the
/// game sent, one it sent while the test held the surface included, else
/// the surface's idle state.
package func benchRestore<Value>(gameLast: Value?, idle: Value) -> Value {
    gameLast ?? idle
}

/// What the body's motors do as a buzz ends: they simply stop, unless the
/// game asked for rumble while the test held them, which is put back.
/// `countAtStart` and `countNow` count the game's rumble commands.
package func benchRumbleAfterTest(countAtStart: UInt64, countNow: UInt64, gameLast: BenchMotors?) -> BenchMotors? {
    countNow > countAtStart ? gameLast : nil
}

/// "Did it work?" for the test a pad ran last, and when that test ended.
package struct BenchQuestion: Equatable, Sendable {
    package let test: BenchTest
    package let endedAtMs: Int64

    package init(test: BenchTest, endedAtMs: Int64) {
        self.test = test
        self.endedAtMs = endedAtMs
    }
}

/// The person's answer, in the contract's words.
package enum BenchResult: String, CaseIterable, Equatable, Sendable {
    case worked
    case didNotWork
}

/// One answered test, `{ test, result, atMs }` as the support file carries
/// it; `atMs` is when the test ended, in milliseconds since the Unix epoch.
package struct BenchOutcome: Equatable, Sendable {
    package let test: BenchTest
    package let result: BenchResult
    package let atMs: Int64

    package init(test: BenchTest, result: BenchResult, atMs: Int64) {
        self.test = test
        self.result = result
        self.atMs = atMs
    }
}

/// The answer to a question, with the time its test ended.
package func benchOutcome(_ question: BenchQuestion, worked: Bool) -> BenchOutcome {
    BenchOutcome(test: question.test, result: worked ? .worked : .didNotWork, atMs: question.endedAtMs)
}

/// The answers each pad keeps for the run.
package let benchOutcomesKept = 20

/// The answers oldest first, the newest kept when the list is full.
package func appendingBenchOutcome(_ outcomes: [BenchOutcome], _ outcome: BenchOutcome, limit: Int = benchOutcomesKept) -> [BenchOutcome] {
    Array((outcomes + [outcome]).suffix(max(limit, 0)))
}
