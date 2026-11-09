// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// A counter several threads advance and read without a lock: the sends
/// the telemetry counts. Every operation is one atomic instruction.
package final class AtomicCounter: Sendable {
    private let word = AtomicWord()

    package init() {}

    /// Returns the post-increment value.
    package func incrementAndGet() -> UInt64 {
        UInt64(bitPattern: word.fetchAdd(1)) &+ 1
    }

    /// Advance by one where nothing reads the new value: a tally.
    package func increment() {
        word.fetchAddRelaxed(1)
    }

    /// Current value without advancing.
    package func current() -> UInt64 {
        UInt64(bitPattern: word.load())
    }

    /// Force a specific value. Production code only ever `reset()`s; tests
    /// use this to place the counter near a threshold.
    package func set(_ newValue: UInt64) {
        word.store(Int64(bitPattern: newValue))
    }

    package func reset() {
        word.store(0)
    }
}

/// An `Int` written on one thread and read or reset on another without a
/// lock: the moment the last report left, which the keep-awake window reads.
package final class AtomicInt: Sendable {
    private let word: AtomicWord

    package init(_ initial: Int = 0) {
        word = AtomicWord(Int64(initial))
    }

    /// Returns the post-increment value.
    package func incrementAndGet() -> Int {
        Int(word.fetchAdd(1)) + 1
    }

    package func set(_ newValue: Int) {
        word.store(Int64(newValue))
    }

    package func get() -> Int {
        Int(word.load())
    }
}

/// A `Bool` several threads read and write without a lock.
package final class AtomicBool: Sendable {
    private let word: AtomicWord

    package init(_ initial: Bool) {
        word = AtomicWord(initial ? 1 : 0)
    }

    /// Stores `newValue` and returns what was there, as one step.
    package func getAndSet(_ newValue: Bool) -> Bool {
        word.exchange(newValue ? 1 : 0) != 0
    }

    package func set(_ newValue: Bool) {
        word.store(newValue ? 1 : 0)
    }

    package func get() -> Bool {
        word.load() != 0
    }
}
