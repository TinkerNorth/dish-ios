// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

@MainActor
final class ClockSourceTests: XCTestCase {

    func testStartingPublishesTheCurrentDateAndTicksEveryMinute() {
        let ticker = ManualTicker()
        let now = ManualNow()
        let clock = ClockSource(ticker: ticker, now: now.read)
        now.date = now.date.addingTimeInterval(500)
        clock.start()
        XCTAssertEqual(clock.state, now.date)
        XCTAssertEqual(ticker.starts, [60])
    }

    func testATickAdvancesTheDate() {
        let ticker = ManualTicker()
        let now = ManualNow()
        let clock = ClockSource(ticker: ticker, now: now.read)
        clock.start()
        now.date = now.date.addingTimeInterval(60)
        ticker.fire()
        XCTAssertEqual(clock.state, now.date)
    }

    func testStoppingStopsTheTicks() {
        let ticker = ManualTicker()
        let now = ManualNow()
        let clock = ClockSource(ticker: ticker, now: now.read)
        clock.start()
        let started = clock.state
        clock.stop()
        now.date = now.date.addingTimeInterval(60)
        ticker.fire()
        XCTAssertEqual(clock.state, started)
        XCTAssertFalse(ticker.running)
    }

    func testARepeatStartOrStopIsANoOp() {
        let ticker = ManualTicker()
        let clock = ClockSource(ticker: ticker, now: ManualNow().read)
        clock.start()
        clock.start()
        XCTAssertEqual(ticker.starts.count, 1, "a second start does not double-tick")
        clock.stop()
        clock.stop()
        XCTAssertEqual(ticker.stops, 1)
    }

    func testAStoppedClockNeverStartedDoesNotTouchTheTicker() {
        let ticker = ManualTicker()
        ClockSource(ticker: ticker, now: ManualNow().read).stop()
        XCTAssertEqual(ticker.stops, 0)
    }
}
