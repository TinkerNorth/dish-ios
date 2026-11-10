// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// Diagnostics: the page's facts come from the live sessions, the pads'
/// records, the lock statistics and the flight recorder, and its Copy goes
/// through the pasteboard seam.
package extension AppModel {

    /// The Diagnostics page's Copy: the transcript the app worded.
    func copyToPasteboard(_ text: String) {
        pasteboard.copy(text)
    }
}

extension AppModel {

    /// The source reads the model's facts on each tick, and the recorder
    /// follows the rows and the controllers from the opening inventory on.
    func wireDiagnostics() {
        diagnostics.useReader { [weak self] in self?.diagnosticsReading() ?? DiagnosticsReading() }
        followDiagnostics()
    }

    private func diagnosticsReading() -> DiagnosticsReading {
        let tally = pads.source.processor.tallySnapshot()
        let readings = controllerFacts.map { controller in
            PadReading(
                controller: controller,
                reports: tally.reports[controller.id] ?? 0,
                motion: tally.motion[controller.id] ?? 0,
                wire: wireFacts(slotId: controller.id)
            )
        }
        return DiagnosticsReading(hosts: network.hub.connections.map(hostDiagnostics), pads: readings)
    }

    /// A pooled satellite's session facts and counters; a remembered one
    /// with no connection in the pool rests.
    private func hostDiagnostics(_ row: ConnectionSummary) -> HostDiagnostics {
        guard row.kind != .moonlight else {
            return HostDiagnostics(summary: row, facts: .resting(id: row.id), counters: .none, moonlight: moonlightDiagnostics(row))
        }
        guard let conn = network.wifi.get(row.id) else {
            return HostDiagnostics(summary: row, facts: .resting(id: row.id), counters: .none)
        }
        return HostDiagnostics(summary: row, facts: hostSessionFacts(of: conn), counters: sessionCounters(of: conn))
    }

    /// A Moonlight host's session, read off its connection when one exists
    /// this run and resting on what its probe said when none does.
    private func moonlightDiagnostics(_ row: ConnectionSummary) -> MoonlightHostDiagnostics {
        let info = network.moonlight.hostFacts[row.id]
        guard let connection = network.moonlight.get(row.id) else { return .resting(info: info) }
        return .read(connection, info: info)
    }

    /// The pad's side of the wire on the satellite it is bound to.
    private func wireFacts(slotId: String) -> SlotWireFacts? {
        guard let connectionId = network.hub.bindings[slotId], let conn = network.wifi.get(connectionId) else { return nil }
        return slotWireFacts(of: conn, slotId: slotId)
    }

    // MARK: - The flight recorder

    /// The recorder diffs the rows and the controllers each time Observation
    /// says they moved.
    func followDiagnostics() {
        withObservationTracking {
            recorder.observeLinks(network.hub.connections)
            recorder.observeSlots(padSnapshots)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.followDiagnostics() }
        }
    }

    private var padSnapshots: [PadSnapshot] {
        controllerFacts.map { controller in
            padSnapshot(
                of: controller,
                boundId: network.hub.bindings[controller.id],
                bound: network.hub.boundConnection(slotId: controller.id)
            )
        }
    }
}
