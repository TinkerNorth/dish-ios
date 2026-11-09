// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import Synchronization

/// A lock with a stable name, `area.thing`, over the value it guards. The
/// plain build holds a `Mutex` and nothing else; a LOCK_STATS build also
/// counts, per thread role, each acquisition, its wait and hold, the locks it
/// nests inside and the blocking calls made while it is held. dish-mac's is
/// a struct over an unfair lock its owner keeps beside the value; Swift 6
/// states the pairing to the compiler instead.
package final class TrackedLock<Value: Sendable>: Sendable {
    private let mutex: Mutex<Value>
    #if LOCK_STATS
    private let id: Int
    #endif

    package init(_ initial: Value, _ name: StaticString) {
        mutex = Mutex(initial)
        #if LOCK_STATS
        id = lockStatsLockId(name)
        #endif
    }

    #if LOCK_STATS
    /// Runs `body` with the value under the lock, counted on this thread.
    package func withLock<Result: Sendable>(_ body: (inout Value) -> Result) -> Result {
        let thread = LockThreadState.current()
        let role = thread.noteAttempt(id)
        let requestedNs = lockStatsNow()
        let attempt = mutex.withLockIfAvailable { value in
            held(&value, body, thread: thread, entry: HeldEntry(role: role, requestedNs: requestedNs, contended: false))
        }
        let outcome = attempt ?? mutex.withLock { value in
            held(&value, body, thread: thread, entry: HeldEntry(role: role, requestedNs: requestedNs, contended: true))
        }
        thread.record(outcome.release)
        return outcome.result
    }

    private struct HeldEntry {
        let role: ThreadRole
        let requestedNs: UInt64
        let contended: Bool
    }

    private struct Outcome<Result: Sendable> {
        let result: Result
        let release: LockRelease?
    }

    private func held<Result: Sendable>(
        _ value: inout Value,
        _ body: (inout Value) -> Result,
        thread: LockThreadState,
        entry: HeldEntry
    ) -> Outcome<Result> {
        thread.noteAcquired(id, role: entry.role, requestedNs: entry.requestedNs, contended: entry.contended)
        let result = body(&value)
        return Outcome(result: result, release: thread.takeHeld(id))
    }
    #else
    /// Runs `body` with the value under the lock.
    package func withLock<Result: Sendable>(_ body: (inout Value) -> Result) -> Result {
        mutex.withLock { value in body(&value) }
    }
    #endif
}
