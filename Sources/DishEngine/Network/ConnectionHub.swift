// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// The satellite pool as the rows read it, and the slot → connection
/// binding table. A satellite carries up to four pads, so binding another
/// slot evicts nothing; a fifth is refused. The rows are derived from the
/// manager's observable state on each read, so Observation tracks them
/// through the manager, and the bindings are the hub's own.
@MainActor
@Observable
package final class ConnectionHub {

    /// slotId → connectionId
    package private(set) var bindings: [String: String] = [:]

    @ObservationIgnored private let wifi: WifiConnectionManager

    package init(wifi: WifiConnectionManager) {
        self.wifi = wifi
    }

    /// One row per pooled or remembered satellite, by name (an unnamed one
    /// by its address). The state folds
    /// the session's own with the "Needs pairing" marker and whether the
    /// last scan heard the satellite:
    /// - `.live` → `.connected`; `.linking` → `.connecting`;
    /// - `.faltering`, and `.stale` while the silent retry is pending, →
    ///   `.unstable`, so the row does not flick to offline between the
    ///   heartbeat drop and the retry;
    /// - no session: marked stale → `.stale`; heard → `.ready`; else `.saved`.
    package var connections: [ConnectionSummary] {
        let pool = wifi.connections
        let remembered = Dictionary(wifi.remembered().map { ($0.id, $0) }) { first, _ in first }
        let discoveredIds = Set(wifi.discoveredServers.map(\.id))
        let staleIds = wifi.staleSatelliteIds
        let ids = Set(pool.keys).union(remembered.keys)
        let rows = ids.compactMap { id -> ConnectionSummary? in
            let conn = pool[id]
            guard let server = conn?.server ?? remembered[id]?.toDiscovered() else { return nil }
            return ConnectionSummary(
                id: id,
                name: server.name,
                address: server.ip,
                udpPort: server.udpPort,
                live: linkState(conn?.state, stale: staleIds.contains(id), heard: discoveredIds.contains(id)),
                latencyMs: conn?.latencyOneWayMs,
                compat: conn?.protocolCompat ?? .unknown,
                boundSlotIds: satelliteSlotIds(id, conn: conn)
            )
        }
        return rows.sorted { ($0.recordName, $0.id) < ($1.recordName, $1.id) }
    }

    package func summary(_ id: String) -> ConnectionSummary? {
        connections.first { $0.id == id }
    }

    /// Every slot bound to a satellite, in the order of the indices it holds there.
    private func satelliteSlotIds(_ id: String, conn: WifiConnection?) -> [String] {
        let bound = bindings.filter { $0.value == id }.keys.sorted()
        let index = { (slotId: String) in conn?.controllerIndex(of: slotId) ?? SatelliteSlots.maxPerSatellite }
        return bound.sorted { index($0) < index($1) }
    }
}

/// A row's state from its session's, the stale marker and the last scan.
func linkState(_ session: SessionState?, stale: Bool, heard: Bool) -> LinkState {
    switch session {
    case .live: .connected
    case .linking: .connecting
    case .faltering, .stale: .unstable
    case .idle, nil: restingLinkState(stale: stale, heard: heard)
    }
}

private func restingLinkState(stale: Bool, heard: Bool) -> LinkState {
    if stale { return .stale }
    return heard ? .ready : .saved
}

// MARK: - Binding

package extension ConnectionHub {

    /// Bind `slotId` to `connectionId`; false when the satellite already
    /// carries four pads or is not in the pool. The slot's prior satellite
    /// lets go, and the satellite takes the pad on the lowest free index
    /// before the table publishes, so the pad's route already knows it. The
    /// pad's capabilities become the descriptor's claims, and its pick the
    /// catalog type it is emulated as.
    @discardableResult
    func bind(slotId: String, connectionId: String, capabilities: ControllerCapabilities, emulateAs: EmulatedPad) -> Bool {
        guard let conn = wifi.pooledConnection(id: connectionId), satelliteHasRoom(connectionId, for: slotId) else { return false }
        if let prior = bindings[slotId], prior != connectionId {
            releaseSlot(slotId, from: prior)
        }
        let type = wifi.resolveControllerType(for: connectionId, emulateAs: emulateAs)
        guard conn.attachSlot(slotId, controllerType: type, capabilities: capabilities, emulateAs: emulateAs) != nil else { return false }
        bindings[slotId] = connectionId
        return true
    }

    /// A satellite carries four pads; a slot it already carries rebinds in place.
    private func satelliteHasRoom(_ connectionId: String, for slotId: String) -> Bool {
        let others = bindings.filter { $0.value == connectionId && $0.key != slotId }.count
        return others < SatelliteSlots.maxPerSatellite
    }

    private func releaseSlot(_ slotId: String, from connectionId: String) {
        wifi.get(connectionId)?.detachSlot(slotId)
    }

    /// The user let the pad go.
    func unbind(slotId: String) {
        release(slotId: slotId)
    }

    /// The pad lets go: the user unbound it, it left, or its satellite
    /// refused it.
    func release(slotId: String) {
        guard let connectionId = bindings.removeValue(forKey: slotId) else { return }
        releaseSlot(slotId, from: connectionId)
    }

    /// The pads attached now: a binding whose pad left is released.
    func keepPresent(_ present: Set<String>) {
        for slotId in bindings.keys where !present.contains(slotId) {
            release(slotId: slotId)
        }
    }

    /// Forget: every pad bound to the connection lets go.
    func forgetBindings(of connectionId: String) {
        for (slotId, bound) in bindings where bound == connectionId {
            release(slotId: slotId)
        }
    }

    /// The pick for a bound slot: a live binding re-sends that pad's
    /// descriptor with the new type.
    func setEmulatedType(slotId: String, _ pad: EmulatedPad) {
        guard let connectionId = bindings[slotId], let conn = wifi.get(connectionId) else { return }
        conn.setEmulateAs(pad, for: slotId)
        conn.setControllerType(wifi.resolveControllerType(for: connectionId, emulateAs: pad), for: slotId)
    }

    /// The bound pad's claims changed; its descriptor follows while live.
    func setCapabilities(slotId: String, _ capabilities: ControllerCapabilities) {
        guard let connectionId = bindings[slotId] else { return }
        wifi.get(connectionId)?.setCapabilities(capabilities, for: slotId)
    }

    func boundConnection(slotId: String) -> ConnectionSummary? {
        guard let connectionId = bindings[slotId] else { return nil }
        return summary(connectionId)
    }
}
