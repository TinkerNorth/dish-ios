// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest
@testable import DishEngine

/// The word the hot paths' atomics stand on: each operation returns what
/// its contract says, and several threads racing on one word lose nothing.
final class AtomicWordTests: XCTestCase {

    func testAWordHoldsItsInitialValue() {
        let word = AtomicWord(-7)
        XCTAssertEqual(word.load(), -7)
        XCTAssertEqual(word.loadRelaxed(), -7)
    }

    func testStoresAreWhatTheNextLoadReads() {
        let word = AtomicWord()
        word.store(41)
        XCTAssertEqual(word.load(), 41)
        word.storeRelaxed(42)
        XCTAssertEqual(word.load(), 42)
    }

    func testFetchAddAndExchangeReturnTheValueBefore() {
        let word = AtomicWord(10)
        XCTAssertEqual(word.fetchAdd(5), 10)
        XCTAssertEqual(word.fetchAddRelaxed(-3), 15)
        XCTAssertEqual(word.exchange(100), 12)
        XCTAssertEqual(word.load(), 100)
    }

    func testCompareExchangeStoresOnlyOverTheExpectedValue() {
        let word = AtomicWord(3)
        XCTAssertFalse(word.compareExchange(expected: 4, desired: 9))
        XCTAssertEqual(word.load(), 3, "a lost exchange leaves the word alone")
        XCTAssertTrue(word.compareExchange(expected: 3, desired: 9))
        XCTAssertEqual(word.load(), 9)
    }

    func testRacingAddsAndCompareExchangeLoopsLoseNothing() {
        let word = AtomicWord()
        Hammer.run { thread in
            if thread % 2 == 0 {
                word.fetchAdd(1)
            } else {
                var seen = word.loadRelaxed()
                while !word.compareExchange(expected: seen, desired: seen + 1) {
                    seen = word.loadRelaxed()
                }
            }
        }
        XCTAssertEqual(word.load(), Int64(Hammer.threads * Hammer.rounds))
    }
}

/// A few threads each running one step many times, all joined before the
/// test reads the result.
enum Hammer {
    static let threads = 4
    static let rounds = 20000

    static func run(_ step: @escaping @Sendable (Int) -> Void) {
        let group = DispatchGroup()
        for thread in 0 ..< threads {
            group.enter()
            Thread {
                for _ in 0 ..< rounds {
                    step(thread)
                }
                group.leave()
            }.start()
        }
        XCTAssertEqual(group.wait(timeout: .now() + 20), .success)
    }
}
