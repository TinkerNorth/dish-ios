// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// The flight recorder's lines, oldest first and bounded, in memory only:
/// they describe this run and nothing about them is worth keeping past it.
/// Fed by `DiagnosticsRecorder`, never from the input path.
@MainActor
package final class DiagnosticsLogStore {
    private let source = StateSource<[DiagnosticsEvent]>(initial: [])
    private var nextSequence = 1

    package init() {}

    package var state: [DiagnosticsEvent] {
        source.state
    }

    package func record(_ events: [DiagnosticsEvent]) {
        guard !events.isEmpty else { return }
        let sequence = nextSequence
        nextSequence += events.count
        source.updateState { appendBounded($0, events, capacity: DiagnosticsLog.capacity, nextSequence: sequence) }
    }
}

/// Feeds the flight recorder by diffing what the pages already render: the
/// connection rows and the controllers, each time Observation says they
/// moved. Its first pass is the run's opening inventory.
@MainActor
package final class DiagnosticsRecorder {

    /// Wall-clock milliseconds, so a copied log lines up with the user's
    /// own account of when something happened.
    package typealias Clock = @MainActor () -> Int64

    private let store: DiagnosticsLogStore
    private let clock: Clock
    private var links: [LinkSnapshot] = []
    private var pads: [PadSnapshot] = []

    package init(store: DiagnosticsLogStore, clock: @escaping Clock = wallClockMilliseconds) {
        self.store = store
        self.clock = clock
    }

    package func observeLinks(_ rows: [ConnectionSummary]) {
        let next = rows.map(linkSnapshot)
        store.record(linkEvents(before: links, after: next, atMs: clock()))
        links = next
    }

    package func observeSlots(_ next: [PadSnapshot]) {
        store.record(padEvents(before: pads, after: next, atMs: clock()))
        pads = next
    }
}

/// The wall clock in milliseconds since 1970, the log's timestamp.
package func wallClockMilliseconds() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
}
