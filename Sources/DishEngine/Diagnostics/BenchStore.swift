// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation

/// The bench's clocks: the uptime a test's steps and captures are timed by,
/// and the wall clock its answer is dated by.
@MainActor
package protocol BenchClock: AnyObject {
    func uptimeMs() -> Int64
    func wallMs() -> Int64
}

/// The device's own clocks.
@MainActor
package final class SystemBenchClock: BenchClock {
    package init() {}

    package func uptimeMs() -> Int64 {
        Int64(uptimeNs() / 1_000_000)
    }

    package func wallMs() -> Int64 {
        wallClockMilliseconds()
    }
}

/// Where the bench stands: the test under way on each pad, a stick test's
/// whole seconds left, each pad's last stick result, the question each pad
/// waits on, and each pad's answers for the run, oldest first; by slot id.
package struct BenchState: Equatable {
    package var running: [String: BenchTest] = [:]
    package var stickSecondsLeft: [String: Int] = [:]
    package var stickResults: [String: StickTestResult] = [:]
    package var asking: [String: BenchQuestion] = [:]
    package var answers: [String: [BenchOutcome]] = [:]

    package init() {}
}

/// The Diagnostics bench (the support contract's "The bench"): one test at
/// a time per pad, each driving the pad from this device alone. A test that
/// writes the pad holds its surface on the pad's feedback queue while its
/// steps land on the bench's tick, then lets it go, and the queue puts back
/// what the game last set; a stick test samples the pad's raw sticks on the
/// same tick. Either ends with "Did it work?", whose answer is the outcome,
/// timed as the test ended. The ticker runs only while a test does.
@MainActor
package final class BenchStore {
    /// dish-mac's inspector polls the sticks every 50 ms; a step lands on
    /// the first tick at or after its time.
    package static let tickSeconds: TimeInterval = 0.05

    private let source = StateSource(initial: BenchState())
    private let feedback: PadFeedback
    private let processor: GamepadInputProcessor
    private let ticker: any Ticker
    private let clock: any BenchClock
    /// The tests driving a pad and the stick tests capturing, by slot id.
    private var runs: [String: BenchRun] = [:]
    private var captures: [String: StickBench] = [:]
    private var ticking = false

    package var state: BenchState {
        source.state
    }

    init(feedback: PadFeedback, processor: GamepadInputProcessor, ticker: any Ticker, clock: any BenchClock) {
        self.feedback = feedback
        self.processor = processor
        self.ticker = ticker
        self.clock = clock
    }

    /// Starts the test on the pad, unless the pad runs one; its question
    /// takes the place of any the pad still waits on.
    func start(_ test: BenchTest, slotId: String) {
        guard state.running[slotId] == nil else { return }
        if let plan = benchPlan(test) {
            return drive(test, plan: plan, slotId: slotId)
        }
        guard let kind = test.stickKind else { return }
        capture(kind, test: test, slotId: slotId)
    }

    /// The answer to the question the pad waits on; nothing when none does.
    func answer(slotId: String, worked: Bool) {
        guard let question = state.asking[slotId] else { return }
        let outcome = benchOutcome(question, worked: worked)
        source.updateState { bench in
            var next = bench
            next.asking[slotId] = nil
            next.answers[slotId] = appendingBenchOutcome(bench.answers[slotId] ?? [], outcome)
            return next
        }
    }

    // MARK: - Running

    private func drive(_ test: BenchTest, plan: BenchPlan, slotId: String) {
        let pad = feedback.pad(for: slotId)
        var run = BenchRun(test: test, plan: plan, startMs: clock.uptimeMs())
        pad.benchBegin(plan.surface)
        for write in run.due(nowMs: run.startMs) {
            pad.benchWrite(write)
        }
        runs[slotId] = run
        began(test, slotId: slotId, secondsLeft: nil)
    }

    private func capture(_ kind: StickTestKind, test: BenchTest, slotId: String) {
        let now = clock.uptimeMs()
        var bench = StickBench()
        bench.start(kind, nowMs: now)
        captures[slotId] = bench
        began(test, slotId: slotId, secondsLeft: bench.secondsLeft(at: now))
    }

    private func began(_ test: BenchTest, slotId: String, secondsLeft: Int?) {
        source.updateState { bench in
            var next = bench
            next.running[slotId] = test
            next.stickSecondsLeft[slotId] = secondsLeft
            next.asking[slotId] = nil
            return next
        }
        keepTicking()
    }

    private func keepTicking() {
        guard !ticking else { return }
        ticking = true
        ticker.start(every: Self.tickSeconds) { [weak self] in self?.tick() }
    }

    private func tick() {
        let now = clock.uptimeMs()
        for slotId in Array(runs.keys) {
            advanceRun(slotId, nowMs: now)
        }
        for slotId in Array(captures.keys) {
            advanceCapture(slotId, nowMs: now)
        }
        guard runs.isEmpty, captures.isEmpty else { return }
        ticking = false
        ticker.stop()
    }

    private func advanceRun(_ slotId: String, nowMs: Int64) {
        guard var run = runs[slotId] else { return }
        let pad = feedback.pad(for: slotId)
        for write in run.due(nowMs: nowMs) {
            pad.benchWrite(write)
        }
        guard run.finished(at: nowMs) else {
            runs[slotId] = run
            return
        }
        runs[slotId] = nil
        pad.benchEnd(run.plan.surface)
        ended(run.test, slotId: slotId, result: nil)
    }

    /// Each tick reads the pad's record again, as the inspectors poll it:
    /// the sticks as the pad sent them, before the dead zones.
    private func advanceCapture(_ slotId: String, nowMs: Int64) {
        guard var bench = captures[slotId], let test = state.running[slotId] else { return }
        if let raw = processor.latestInput(slotId)?.raw {
            bench.sample(left: InputReadout.stickSample(x: raw.lx, y: raw.ly), right: InputReadout.stickSample(x: raw.rx, y: raw.ry))
        }
        bench.advance(nowMs: nowMs)
        guard bench.phase == .done else {
            captures[slotId] = bench
            countDown(slotId, secondsLeft: bench.secondsLeft(at: nowMs))
            return
        }
        captures[slotId] = nil
        ended(test, slotId: slotId, result: bench.result)
    }

    private func countDown(_ slotId: String, secondsLeft: Int) {
        source.updateState { bench in
            var next = bench
            next.stickSecondsLeft[slotId] = secondsLeft
            return next
        }
    }

    /// The run is over: the pad asks whether it worked, dated now.
    private func ended(_ test: BenchTest, slotId: String, result: StickTestResult?) {
        let question = BenchQuestion(test: test, endedAtMs: clock.wallMs())
        source.updateState { bench in
            var next = bench
            next.running[slotId] = nil
            next.stickSecondsLeft[slotId] = nil
            next.stickResults[slotId] = result ?? bench.stickResults[slotId]
            next.asking[slotId] = question
            return next
        }
    }
}
