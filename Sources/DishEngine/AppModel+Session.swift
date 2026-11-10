// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The session the accessory shows on every tab: the live PC, a satellite
/// or a Moonlight host, carrying the most pads, its pads, its latency, and
/// whether it stopped answering; Reconnect brings a faltering one back.
package extension AppModel {

    /// Nil while no PC has a session up.
    internal var sessionFact: SessionFact? {
        guard let row = sessionConnection else { return nil }
        return SessionFact(
            pcName: row.name,
            pads: row.boundSlotIds.count,
            latencyMs: row.latencyMs.map(wholeMilliseconds),
            phase: sessionPhase(row.live)
        )
    }

    /// The accessory's Reconnect: a session that stopped answering closes
    /// and opens again; one that is down is reached for. A Moonlight host's
    /// session is reopened by its manager, which resumes the app it left.
    func reconnect() {
        guard let row = sessionConnection else { return }
        guard !ConnectionHub.isMoonlight(row.id) else { return network.moonlight.retrySessions() }
        if row.live == .unstable { network.wifi.disconnect(id: row.id) }
        connect(row.id)
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
}

/// A live link streams; one whose acks falter has stopped responding.
func sessionPhase(_ live: LinkState) -> SessionPhase {
    switch live {
    case .unstable: .stoppedResponding
    case .connected, .stale, .saved, .ready, .connecting: .streaming
    }
}
