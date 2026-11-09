// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

#if LOCK_STATS
import Foundation
import Synchronization

/// One lock's counts on one thread role.
package struct LockRoleCounters: Equatable {
    package var acquisitions: UInt64 = 0
    package var contended: UInt64 = 0
    package var waitTotalNs: UInt64 = 0
    package var waitMaxNs: UInt64 = 0
    package var holdTotalNs: UInt64 = 0
    package var holdMaxNs: UInt64 = 0

    package init() {}

    mutating func add(_ release: LockRelease) {
        acquisitions += 1
        if release.contended { contended += 1 }
        waitTotalNs &+= release.waitNs
        waitMaxNs = max(waitMaxNs, release.waitNs)
        holdTotalNs &+= release.holdNs
        holdMaxNs = max(holdMaxNs, release.holdNs)
    }

    mutating func merge(_ other: LockRoleCounters) {
        acquisitions += other.acquisitions
        contended += other.contended
        waitTotalNs &+= other.waitTotalNs
        waitMaxNs = max(waitMaxNs, other.waitMaxNs)
        holdTotalNs &+= other.holdTotalNs
        holdMaxNs = max(holdMaxNs, other.holdMaxNs)
    }
}

/// Two names in order: an outer lock and a lock taken inside it, or a
/// blocking region and a lock held across it.
package struct LockPair: Hashable, Comparable {
    package let first: String
    package let second: String

    package init(_ first: String, _ second: String) {
        self.first = first
        self.second = second
    }

    package static func < (lhs: LockPair, rhs: LockPair) -> Bool {
        (lhs.first, lhs.second) < (rhs.first, rhs.second)
    }
}

/// Every tracked lock's counts since the last reset, merged across threads.
package struct LockStatsSnapshot: Equatable {
    package var locks: [String: [ThreadRole: LockRoleCounters]] = [:]
    package var edges: [LockPair: UInt64] = [:]
    package var blocking: [LockPair: UInt64] = [:]
    package var regions: [String: UInt64] = [:]

    package init() {}

    /// The locks `role` acquired at least once.
    package func acquired(by role: ThreadRole) -> Set<String> {
        Set(locks.filter { ($0.value[role]?.acquisitions ?? 0) > 0 }.keys)
    }

    package func counters(_ lock: String, _ role: ThreadRole) -> LockRoleCounters {
        locks[lock]?[role] ?? LockRoleCounters()
    }
}

package func lockStatsSnapshot() -> LockStatsSnapshot {
    lockStatsRegistry.snapshot()
}

package func resetLockStats() {
    lockStatsRegistry.reset()
}

let threadRoleKey = DispatchSpecificKey<ThreadRole>()

func lockStatsNow() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
}

func lockStatsLockId(_ name: StaticString) -> Int {
    lockStatsRegistry.lockId(name.description)
}

func lockStatsRegionId(_ name: StaticString) -> Int {
    lockStatsRegistry.regionId(name.description)
}

/// The statistics build counts every lock wherever it is made, so its
/// registry is one per process; the plain build has none.
private let lockStatsRegistry = LockStatsRegistry()

private let lockThreadStateKey: pthread_key_t = {
    var key = pthread_key_t()
    let created = pthread_key_create(&key, nil)
    precondition(created == 0, "LOCK_STATS needs a thread-specific key")
    return key
}()

private func pairKey(_ first: Int, _ second: Int) -> Int {
    first << 16 | second
}

/// One lock's release, as the thread that held it counts it.
struct LockRelease {
    let lock: Int
    let role: ThreadRole
    let waitNs: UInt64
    let contended: Bool
    let holdNs: UInt64
}

/// The names and every thread's counts. Its own mutex and each thread's are
/// leaves: nothing is acquired while either is held.
final class LockStatsRegistry: Sendable {
    private struct Names {
        var locks: [String] = []
        var lockIds: [String: Int] = [:]
        var regions: [String] = []
        var regionIds: [String: Int] = [:]
        var threads: [LockThreadState] = []
    }

    private let names = Mutex(Names())

    func lockId(_ name: String) -> Int {
        names.withLock { Self.intern(name, names: &$0.locks, ids: &$0.lockIds) }
    }

    func regionId(_ name: String) -> Int {
        names.withLock { Self.intern(name, names: &$0.regions, ids: &$0.regionIds) }
    }

    func register(_ thread: LockThreadState) {
        names.withLock { $0.threads.append(thread) }
    }

    func snapshot() -> LockStatsSnapshot {
        let (known, everyThread) = names.withLock { (LockStatsNames(locks: $0.locks, regions: $0.regions), $0.threads) }
        var snapshot = LockStatsSnapshot()
        for thread in everyThread {
            thread.merge(into: &snapshot, names: known)
        }
        return snapshot
    }

    func reset() {
        let everyThread = names.withLock { $0.threads }
        for thread in everyThread {
            thread.clear()
        }
    }

    private static func intern(_ name: String, names: inout [String], ids: inout [String: Int]) -> Int {
        if let known = ids[name] { return known }
        let id = names.count
        names.append(name)
        ids[name] = id
        return id
    }
}

/// The names behind the ids, as a snapshot reads them.
struct LockStatsNames {
    let locks: [String]
    let regions: [String]

    func lock(_ id: Int) -> String? {
        locks.indices.contains(id) ? locks[id] : nil
    }

    func region(_ id: Int) -> String? {
        regions.indices.contains(id) ? regions[id] : nil
    }
}

/// One thread's held locks and counts, under a mutex of its own that only
/// that thread and a snapshot ever take.
final class LockThreadState: Sendable {
    private struct Held {
        let lock: Int
        let role: ThreadRole
        let waitNs: UInt64
        let contended: Bool
        let sinceNs: UInt64
    }

    private struct Counts {
        var role: ThreadRole?
        var held: [Held] = []
        var counters: [Int: LockRoleCounters] = [:]
        var edges: [Int: UInt64] = [:]
        var blocking: [Int: UInt64] = [:]
        var regionHits: [Int: UInt64] = [:]
    }

    private static let roleCount = ThreadRole.allCases.count

    private let counts = Mutex(Counts())

    static func current() -> LockThreadState {
        if let raw = pthread_getspecific(lockThreadStateKey) {
            return Unmanaged<LockThreadState>.fromOpaque(raw).takeUnretainedValue()
        }
        let state = LockThreadState()
        lockStatsRegistry.register(state)
        let stored = pthread_setspecific(lockThreadStateKey, Unmanaged.passUnretained(state).toOpaque())
        precondition(stored == 0, "LOCK_STATS could not keep a thread's state")
        return state
    }

    func enter(_ role: ThreadRole) {
        counts.withLock { $0.role = role }
    }

    /// The role this acquisition counts under, after counting an edge from
    /// every lock the thread already holds to `lock`.
    func noteAttempt(_ lock: Int) -> ThreadRole {
        let marked = DispatchQueue.getSpecific(key: threadRoleKey)
        let onMain = pthread_main_np() != 0
        return counts.withLock { state in
            for outer in state.held {
                state.edges[pairKey(outer.lock, lock), default: 0] += 1
            }
            return marked ?? state.role ?? (onMain ? .main : .other)
        }
    }

    func noteAcquired(_ lock: Int, role: ThreadRole, requestedNs: UInt64, contended: Bool) {
        let acquiredNs = lockStatsNow()
        let waitNs = acquiredNs > requestedNs ? acquiredNs - requestedNs : 0
        let entry = Held(lock: lock, role: role, waitNs: waitNs, contended: contended, sinceNs: acquiredNs)
        counts.withLock { $0.held.append(entry) }
    }

    func takeHeld(_ lock: Int) -> LockRelease? {
        let releasedNs = lockStatsNow()
        return counts.withLock { state in
            guard let index = state.held.lastIndex(where: { $0.lock == lock }) else { return nil }
            let entry = state.held.remove(at: index)
            let holdNs = releasedNs > entry.sinceNs ? releasedNs - entry.sinceNs : 0
            return LockRelease(lock: entry.lock, role: entry.role, waitNs: entry.waitNs, contended: entry.contended, holdNs: holdNs)
        }
    }

    func record(_ release: LockRelease?) {
        guard let release else { return }
        let key = release.lock * Self.roleCount + release.role.rawValue
        counts.withLock { $0.counters[key, default: LockRoleCounters()].add(release) }
    }

    func noteBlocking(_ region: Int) {
        counts.withLock { state in
            state.regionHits[region, default: 0] += 1
            for entry in state.held {
                state.blocking[pairKey(region, entry.lock), default: 0] += 1
            }
        }
    }

    func merge(into snapshot: inout LockStatsSnapshot, names: LockStatsNames) {
        let copy = counts.withLock { ($0.counters, $0.edges, $0.blocking, $0.regionHits) }
        for (key, counters) in copy.0 {
            guard let name = names.lock(key / Self.roleCount), let role = ThreadRole(rawValue: key % Self.roleCount) else { continue }
            snapshot.locks[name, default: [:]][role, default: LockRoleCounters()].merge(counters)
        }
        for (key, count) in copy.1 {
            guard let outer = names.lock(key >> 16), let inner = names.lock(key & 0xFFFF) else { continue }
            snapshot.edges[LockPair(outer, inner), default: 0] += count
        }
        for (key, count) in copy.2 {
            guard let region = names.region(key >> 16), let lock = names.lock(key & 0xFFFF) else { continue }
            snapshot.blocking[LockPair(region, lock), default: 0] += count
        }
        for (key, count) in copy.3 {
            guard let region = names.region(key) else { continue }
            snapshot.regions[region, default: 0] += count
        }
    }

    func clear() {
        counts.withLock { state in
            state.counters = [:]
            state.edges = [:]
            state.blocking = [:]
            state.regionHits = [:]
        }
    }
}
#endif
