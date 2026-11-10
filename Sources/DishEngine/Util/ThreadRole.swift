// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The job of the thread a tracked lock is taken on. A queue is marked where
/// it is made and an owned thread where it starts; only LOCK_STATS reads it.
/// dish-mac's Direct reader and audio roles have no thread here.
package enum ThreadRole: Int, CaseIterable {
    /// GameController's handler queue.
    case input
    /// The satellite's receive loop.
    case receive
    /// The satellite's heartbeat and the Moonlight session's tick.
    case heartbeat
    /// The queue that drives the pads' actuators.
    case feedback
    /// The Moonlight control socket's queue.
    case moonlightUdp
    /// The main thread, and so the main actor.
    case main
    /// Anything unmarked.
    case other

    package var name: String {
        switch self {
        case .input: "Input"
        case .receive: "Receive"
        case .heartbeat: "Heartbeat"
        case .feedback: "Feedback"
        case .moonlightUdp: "MoonlightUdp"
        case .main: "Main"
        case .other: "Other"
        }
    }

    /// A serial queue that runs as this role.
    package func queue(label: String, qos: DispatchQoS) -> DispatchSerialQueue {
        let made = DispatchSerialQueue(label: label, qos: qos)
        mark(made)
        return made
    }

    package func mark(_ queue: DispatchQueue) {
        #if LOCK_STATS
        queue.setSpecific(key: threadRoleKey, value: self)
        #endif
    }

    /// The calling thread runs as this role from now on: a thread the app
    /// owns, never a queue's worker.
    package func enterThread() {
        #if LOCK_STATS
        LockThreadState.current().enter(self)
        #endif
    }
}

/// Marks a call that can block or enter the kernel; a LOCK_STATS build
/// counts it and every tracked lock held across it.
func blockingRegion(_ name: StaticString) {
    #if LOCK_STATS
    LockThreadState.current().noteBlocking(lockStatsRegionId(name))
    #endif
}
