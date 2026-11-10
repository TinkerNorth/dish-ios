// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation

/// One PC as Diagnostics reads it: the row the pages draw, its session's
/// own account of itself and the data plane's counters.
package struct HostDiagnostics: Equatable, Identifiable {
    package let summary: ConnectionSummary
    /// The satellite session; resting for a PC with no connection in the pool.
    package let facts: HostSessionFacts
    package let counters: SessionCounters

    package var id: String {
        summary.id
    }

    package init(summary: ConnectionSummary, facts: HostSessionFacts, counters: SessionCounters) {
        self.summary = summary
        self.facts = facts
        self.counters = counters
    }
}

/// One pad's rates, quantized as dish-mac's inspector shows them.
package struct PadRates: Equatable {
    package let reportHz: Int
    package let motionHz: Int

    package init(reportHz: Int, motionHz: Int) {
        self.reportHz = reportHz
        self.motionHz = motionHz
    }
}

/// One controller as Diagnostics reads it: the fact the Controllers tab
/// draws, its rates and published reports, and its side of the wire.
package struct PadDiagnostics: Equatable, Identifiable {
    package let controller: ControllerFact
    package let rates: PadRates
    package let reports: UInt64
    /// Nil for an unbound pad, or one whose satellite carries no descriptor
    /// for it yet.
    package let wire: SlotWireFacts?

    package var id: String {
        controller.id
    }

    package init(controller: ControllerFact, rates: PadRates, reports: UInt64, wire: SlotWireFacts?) {
        self.controller = controller
        self.rates = rates
        self.reports = reports
        self.wire = wire
    }
}

/// One tracked lock's counts on one thread role, in a `LOCK_STATS` build.
package struct LockFact: Equatable, Identifiable {
    package let lock: String
    package let role: ThreadRole
    package let acquisitions: UInt64
    package let contended: UInt64
    package let waitMaxNs: UInt64
    package let holdMaxNs: UInt64

    package var id: String {
        "\(lock):\(role.rawValue)"
    }

    package init(lock: String, role: ThreadRole, acquisitions: UInt64, contended: UInt64, waitMaxNs: UInt64, holdMaxNs: UInt64) {
        self.lock = lock
        self.role = role
        self.acquisitions = acquisitions
        self.contended = contended
        self.waitMaxNs = waitMaxNs
        self.holdMaxNs = holdMaxNs
    }
}

package struct DiagnosticsSnapshot: Equatable {
    package let hosts: [HostDiagnostics]
    package let pads: [PadDiagnostics]
    /// Nil in a plain build, which counts no lock.
    package let locks: [LockFact]?

    package init(hosts: [HostDiagnostics] = [], pads: [PadDiagnostics] = [], locks: [LockFact]? = nil) {
        self.hosts = hosts
        self.pads = pads
        self.locks = locks
    }
}

/// A pad as the model reads it for the source on each tick: the fact, the
/// counts its rates come from, and its side of the wire.
package struct PadReading: Equatable {
    package let controller: ControllerFact
    package let reports: UInt64
    package let motion: UInt64
    package let wire: SlotWireFacts?

    package init(controller: ControllerFact, reports: UInt64, motion: UInt64, wire: SlotWireFacts?) {
        self.controller = controller
        self.reports = reports
        self.motion = motion
        self.wire = wire
    }
}

/// What the model reads for the source on each tick.
package struct DiagnosticsReading: Equatable {
    package let hosts: [HostDiagnostics]
    package let pads: [PadReading]

    package init(hosts: [HostDiagnostics] = [], pads: [PadReading] = []) {
        self.hosts = hosts
        self.pads = pads
    }
}

/// One rate tracker per stream, so a sample turns counts into rates; a pad
/// that left drops out.
struct TelemetryRates {
    private var reports: [String: InputRateTracker] = [:]
    private var motion: [String: InputRateTracker] = [:]

    mutating func sample(_ pads: [PadReading], nowUs: UInt64) -> [PadDiagnostics] {
        let ids = Set(pads.map(\.controller.id))
        reports = reports.filter { ids.contains($0.key) }
        motion = motion.filter { ids.contains($0.key) }
        return pads.map { pad in
            let reportHz = reports[pad.controller.id, default: InputRateTracker()].sample(count: pad.reports, nowUs: nowUs)
            let motionHz = motion[pad.controller.id, default: InputRateTracker()].sample(count: pad.motion, nowUs: nowUs)
            let rates = PadRates(reportHz: reportHz, motionHz: motionHz)
            return PadDiagnostics(controller: pad.controller, rates: rates, reports: pad.reports, wire: pad.wire)
        }
    }
}

/// What the app sees right now, for the Diagnostics page: every figure is
/// one the rest of the app already acts on, not a second measurement. The
/// ack-fed numbers and the counters change without a publication, so a
/// 1 Hz tick re-reads them while the page is open; `start` arms it and
/// `stop` ends it. The reader is the model's, set once it has its stores.
@MainActor
package final class DiagnosticsSource {
    static let tickSeconds: TimeInterval = 1

    private let ticker: any Ticker
    private let clockUs: @MainActor () -> UInt64
    private let source = StateSource<DiagnosticsSnapshot>(initial: DiagnosticsSnapshot())
    private var read: @MainActor () -> DiagnosticsReading = { DiagnosticsReading() }
    private var rates = TelemetryRates()
    private var running = false

    package init(ticker: any Ticker, clockUs: @escaping @MainActor () -> UInt64 = uptimeMicroseconds) {
        self.ticker = ticker
        self.clockUs = clockUs
    }

    package var state: DiagnosticsSnapshot {
        source.state
    }

    /// Whether the tick runs: the page is on screen.
    package var isTicking: Bool {
        running
    }

    /// The facts to read on each tick, set once the owner has its stores.
    package func useReader(_ reader: @escaping @MainActor () -> DiagnosticsReading) {
        read = reader
    }

    package func start() {
        guard !running else { return }
        running = true
        refresh()
        ticker.start(every: Self.tickSeconds, refresh)
    }

    package func stop() {
        guard running else { return }
        running = false
        ticker.stop()
    }

    package func refresh() {
        let reading = read()
        let pads = rates.sample(reading.pads, nowUs: clockUs())
        source.setState(DiagnosticsSnapshot(hosts: reading.hosts, pads: pads, locks: lockFacts()))
    }
}

/// The uptime clock in microseconds, the rates' basis.
package func uptimeMicroseconds() -> UInt64 {
    uptimeNs() / 1000
}

/// Every tracked lock's counts by thread role, by name then role; nil in a
/// plain build, which counts none.
package func lockFacts() -> [LockFact]? {
    #if LOCK_STATS
    let facts = lockStatsSnapshot().locks.flatMap { lock, roles in
        roles.map { role, counters in
            LockFact(
                lock: lock,
                role: role,
                acquisitions: counters.acquisitions,
                contended: counters.contended,
                waitMaxNs: counters.waitMaxNs,
                holdMaxNs: counters.holdMaxNs
            )
        }
    }
    return facts.sorted { ($0.lock, $0.role.rawValue) < ($1.lock, $1.role.rawValue) }
    #else
    return nil
    #endif
}
