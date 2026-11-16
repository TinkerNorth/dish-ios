// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The session the accessory shows on every tab: the live PC, a satellite
/// or a Moonlight host, carrying the most pads, its pads, its latency, and
/// whether it stopped answering; Reconnect brings a faltering one back,
/// and while the person's reach for a PC with pads bound is under way, the
/// accessory shows it coming back.
package extension AppModel {

    /// Nil while no PC has a session up, none is being brought back, and
    /// none with pads bound carries a failure.
    internal var sessionFact: SessionFact? {
        if let row = sessionConnection {
            return SessionFact(
                id: row.id,
                pcName: row.name,
                pads: row.boundSlotIds.count,
                latencyMs: row.latencyMs.map(wholeMilliseconds),
                phase: sessionPhase(row.live, notice: noticeOf(row))
            )
        }
        if let row = reconnectingConnection {
            return SessionFact(id: row.id, pcName: row.name, pads: row.boundSlotIds.count, latencyMs: nil, phase: .reconnecting)
        }
        guard let failed = failedLink else { return nil }
        return SessionFact(
            id: failed.row.id,
            pcName: failed.row.name,
            pads: failed.row.boundSlotIds.count,
            latencyMs: nil,
            phase: .failed(failed.failure)
        )
    }

    private func noticeOf(_ row: ConnectionSummary) -> ConnectionFailure? {
        attemptNotice(attemptNotices.state[row.id], live: row.live)
    }

    /// The accessory's Reconnect: a session that stopped answering closes
    /// and opens again; one that is down is reached for. A Moonlight host's
    /// session is reopened by its manager, which resumes the app it left.
    func reconnect() {
        guard let row = sessionConnection ?? failedLink?.row else { return }
        guard !ConnectionHub.isMoonlight(row.id) else { return network.moonlight.retrySessions() }
        reconnect(row.id)
    }

    /// The app is leaving the foreground: iOS will suspend it, so every
    /// session closes the graceful way; a Moonlight host keeps its app
    /// running for the return to resume.
    func enteredBackground() {
        network.wifi.closeSessionsForBackground()
        network.moonlight.stopSessionsForBackground()
    }

    /// Back in the foreground: the resting satellites are reached for now,
    /// and the hosts the bindings ask for open again.
    func enteredForeground() {
        network.wifi.resumeInForeground()
        network.moonlight.retrySessions()
    }

    private var sessionConnection: ConnectionSummary? {
        let up = network.hub.connections.filter { sessionIsUp($0.live) }
        return up.max { $0.boundSlotIds.count < $1.boundSlotIds.count }
    }

    /// The PC the person reached for that carries pads, while the pool
    /// reaches it; a silent retry is never one.
    private var reconnectingConnection: ConnectionSummary? {
        let reachedFor = reaching.state
        let reached = network.hub.connections.filter { reachedFor.contains($0.id) && $0.live == .connecting && !$0.boundSlotIds.isEmpty }
        return reached.max { $0.boundSlotIds.count < $1.boundSlotIds.count }
    }

    /// A PC with pads bound whose rows carry a failure.
    private struct FailedLink {
        let row: ConnectionSummary
        let failure: ConnectionFailure
    }

    /// The PC with the most pads bound whose last attempt failed: the
    /// accessory carries the failure to every tab, with Reconnect.
    private var failedLink: FailedLink? {
        let failed = network.hub.connections.compactMap { row in noticeOf(row).map { FailedLink(row: row, failure: $0) } }
        let carrying = failed.filter { !$0.row.boundSlotIds.isEmpty }
        return carrying.max { $0.row.boundSlotIds.count < $1.row.boundSlotIds.count }
    }
}

/// A live link streams; one whose acks falter has stopped responding, or
/// failed for the reason its rows carry.
func sessionPhase(_ live: LinkState, notice: ConnectionFailure? = nil) -> SessionPhase {
    switch live {
    case .unstable: notice.map(SessionPhase.failed) ?? .stoppedResponding
    case .connected, .stale, .saved, .ready, .connecting: .streaming
    }
}
