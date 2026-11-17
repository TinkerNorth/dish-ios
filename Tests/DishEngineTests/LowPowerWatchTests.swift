// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// Android's power saver as the watch keeps it: the seconds without a touch
/// count up to the delay, the last five show, the end is due until the
/// shell takes it, a touch starts it over, and Never or a cover rests it.
@MainActor
final class LowPowerWatchTests: XCTestCase {

    private let ticker = ManualTicker()
    private lazy var watch = LowPowerWatch(ticker: ticker)

    private func fire(_ times: Int) {
        for _ in 0 ..< times {
            ticker.fire()
        }
    }

    func testAnArmedWatchCountsTheLastFiveSecondsDownAndThenIsDue() {
        watch.arm(.tenSeconds, while: true)
        XCTAssertTrue(ticker.running)
        XCTAssertEqual(ticker.starts, [1])
        XCTAssertEqual(watch.state, .idle)
        fire(4)
        XCTAssertEqual(watch.state, .idle, "the first seconds pass in silence")
        fire(1)
        XCTAssertEqual(watch.state, LowPowerFact(countdown: 5, due: false))
        fire(4)
        XCTAssertEqual(watch.state, LowPowerFact(countdown: 1, due: false))
        fire(1)
        XCTAssertEqual(watch.state, LowPowerFact(countdown: nil, due: true))
        fire(1)
        XCTAssertEqual(watch.state, LowPowerFact(countdown: nil, due: true), "due until the shell takes it")
    }

    func testATouchStartsTheCountOver() {
        watch.arm(.tenSeconds, while: true)
        fire(7)
        XCTAssertEqual(watch.state.countdown, 3)
        watch.touched()
        XCTAssertEqual(watch.state, .idle)
        fire(5)
        XCTAssertEqual(watch.state.countdown, 5, "a full delay again")
    }

    func testTheShellTakingTheDueStartsTheCountOver() {
        watch.arm(.tenSeconds, while: true)
        fire(10)
        XCTAssertTrue(watch.state.due)
        watch.handled()
        XCTAssertEqual(watch.state, .idle)
        XCTAssertTrue(ticker.running, "still armed: the dim may have been refused")
    }

    func testNeverOrACoverRestsTheWatch() {
        watch.arm(.never, while: true)
        XCTAssertFalse(ticker.running)
        watch.arm(.twentySeconds, while: false)
        XCTAssertFalse(ticker.running)
        watch.arm(.twentySeconds, while: true)
        fire(16)
        XCTAssertEqual(watch.state.countdown, 4)
        watch.arm(.twentySeconds, while: false)
        XCTAssertEqual(watch.state, .idle)
        XCTAssertEqual(ticker.stops, 1)
        XCTAssertFalse(ticker.running)
    }

    func testAChangeOfDelayKeepsTheCount() {
        watch.arm(.twentySeconds, while: true)
        fire(8)
        XCTAssertEqual(watch.state, .idle)
        watch.arm(.tenSeconds, while: true)
        XCTAssertEqual(watch.state.countdown, 2, "eight seconds idle against ten")
        XCTAssertEqual(ticker.starts, [1], "not started again")
    }

    func testATouchWhileRestedChangesNothing() {
        watch.touched()
        XCTAssertEqual(watch.state, .idle)
        XCTAssertFalse(ticker.running)
    }

    /// The fact is a rule over the delay and the seconds idle.
    func testTheFactShowsTheLastFiveSecondsAndIsDueAtZero() {
        XCTAssertEqual(lowPowerFact(delay: .twentySeconds, idleSeconds: 0), .idle)
        XCTAssertEqual(lowPowerFact(delay: .twentySeconds, idleSeconds: 14), .idle)
        XCTAssertEqual(lowPowerFact(delay: .twentySeconds, idleSeconds: 15), LowPowerFact(countdown: 5, due: false))
        XCTAssertEqual(lowPowerFact(delay: .twentySeconds, idleSeconds: 19), LowPowerFact(countdown: 1, due: false))
        XCTAssertEqual(lowPowerFact(delay: .twentySeconds, idleSeconds: 20), LowPowerFact(countdown: nil, due: true))
        XCTAssertEqual(lowPowerFact(delay: .twentySeconds, idleSeconds: 30), LowPowerFact(countdown: nil, due: true))
        XCTAssertEqual(lowPowerFact(delay: .tenSeconds, idleSeconds: 5), LowPowerFact(countdown: 5, due: false))
    }
}
