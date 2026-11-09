// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Synchronization

/// A 64-bit word several threads read and write without a lock, over
/// `Synchronization.Atomic`. dish-mac's word is a view onto storage its
/// owner allocates, since macOS 13 had no `Atomic`; here the word owns its
/// storage, so it is a class its owners hold by `let`.
package final class AtomicWord: Sendable {
    private let value: Atomic<Int64>

    package init(_ initial: Int64 = 0) {
        value = Atomic(initial)
    }

    /// Acquire: what the storing thread wrote before its store is visible.
    package func load() -> Int64 {
        value.load(ordering: .acquiring)
    }

    package func loadRelaxed() -> Int64 {
        value.load(ordering: .relaxed)
    }

    /// Release: everything written before it is visible to an acquiring load.
    package func store(_ newValue: Int64) {
        value.store(newValue, ordering: .releasing)
    }

    package func storeRelaxed(_ newValue: Int64) {
        value.store(newValue, ordering: .relaxed)
    }

    /// The value before the add.
    @discardableResult
    package func fetchAdd(_ delta: Int64) -> Int64 {
        value.wrappingAdd(delta, ordering: .acquiringAndReleasing).oldValue
    }

    @discardableResult
    package func fetchAddRelaxed(_ delta: Int64) -> Int64 {
        value.wrappingAdd(delta, ordering: .relaxed).oldValue
    }

    /// The value before the store.
    package func exchange(_ newValue: Int64) -> Int64 {
        value.exchange(newValue, ordering: .acquiringAndReleasing)
    }

    /// Stores `desired` only while the word holds `expected`.
    package func compareExchange(expected: Int64, desired: Int64) -> Bool {
        value.compareExchange(expected: expected, desired: desired, ordering: .acquiringAndReleasing).exchanged
    }
}

/// Orders the loads before it ahead of every load and store after it: a
/// seqlock reader's fence between its field loads and its second sequence load.
func atomicFenceAcquire() {
    atomicMemoryFence(ordering: .acquiring)
}

/// Orders the loads and stores before it ahead of every store after it: a
/// seqlock writer's fence between its odd sequence and its field stores.
func atomicFenceRelease() {
    atomicMemoryFence(ordering: .releasing)
}
