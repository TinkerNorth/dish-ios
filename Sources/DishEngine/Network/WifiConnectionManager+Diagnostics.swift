// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What the support file asks of each satellite: its own snapshot of this
/// connection over the authenticated client, and the copy the pool already
/// holds for one that cannot answer.
extension WifiConnectionManager {

    /// The diagnostics route's answer for a satellite with a live session;
    /// nil for one with none, which is not asked.
    func connectionDiagnostics(_ id: String) async -> SnapshotReply? {
        guard let conn = connections[id], conn.hasLiveSession, let connectionId = conn.connectionId else { return nil }
        let server = conn.server
        return await http.getConnectionDiagnostics(
            ip: server.ip,
            port: server.httpPort,
            connectionId: connectionId,
            deviceId: deviceId,
            hmacProof: proofFor(id),
            timeout: snapshotTimeoutSeconds
        )
    }

    /// The capabilities and the catalog's version the pool last read from
    /// the satellite; nil when it never answered the probe.
    func capabilitiesFacts(_ id: String) -> SatelliteCapabilitiesFacts? {
        let catalogVersion = catalogs[id].map(\.catalogVersion)
        return capabilities[id]?.facts(catalogVersion: catalogVersion)
    }
}
