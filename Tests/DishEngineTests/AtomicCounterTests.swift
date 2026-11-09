// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest
@testable import DishEngine

/// The counters the hot path tallies with: each returns what it says, and
/// racing threads lose no step.
final class AtomicCounterTests: XCTestCase {

    func testIncrementAndGetReturnsPostIncrementValue() {
        let counter = AtomicCounter()
        XCTAssertEqual(counter.incrementAndGet(), 1)
        XCTAssertEqual(counter.incrementAndGet(), 2)
    }

    func testResetReturnsToZero() {
        let counter = AtomicCounter()
        counter.increment()
        counter.reset()
        XCTAssertEqual(counter.current(), 0)
    }

    func testCurrentReadsWithoutAdvancing() {
        let counter = AtomicCounter()
        counter.increment()
        XCTAssertEqual(counter.current(), 1)
        XCTAssertEqual(counter.current(), 1)
    }

    func testSetPlacesTheSequenceExactly() {
        let counter = AtomicCounter()
        counter.set(UInt64.max - 1)
        XCTAssertEqual(counter.incrementAndGet(), UInt64.max)
    }

    func testConcurrentIncrementsAreAtomic() {
        let counter = AtomicCounter()
        Hammer.run { _ in counter.increment() }
        XCTAssertEqual(counter.current(), UInt64(Hammer.threads * Hammer.rounds))
    }

    func testAtomicIntIncrementGetSet() {
        let value = AtomicInt(5)
        XCTAssertEqual(value.get(), 5)
        XCTAssertEqual(value.incrementAndGet(), 6)
        value.set(-2)
        XCTAssertEqual(value.get(), -2)
    }

    func testAtomicBoolGetSet() {
        let flag = AtomicBool(false)
        XCTAssertFalse(flag.getAndSet(true))
        XCTAssertTrue(flag.get())
        flag.set(false)
        XCTAssertFalse(flag.get())
    }
}
