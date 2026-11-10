// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// The satellite pool and the Moonlight hosts as the rows read them, and
/// the slot → connection binding table. A satellite and a Moonlight host
/// each carry up to four pads, so binding another slot evicts nothing; a
/// fifth is refused at a satellite, and what the bindings ask of each host
/// is converged by the app. The rows are derived from the managers'
/// observable state on each read, so Observation tracks them through the
/// managers, and the bindings are the hub's own.
@MainActor
@Observable
package final class ConnectionHub {

    /// slotId → connectionId
    package private(set) var bindings: [String: String] = [:]

    @ObservationIgnored private let wifi: WifiConnectionManager
    @ObservationIgnored private let moonlight: MoonlightConnectionManager?

    package init(wifi: WifiConnectionManager, moonlight: MoonlightConnectionManager? = nil) {
        self.wifi = wifi
        self.moonlight = moonlight
    }

    /// A Moonlight host's id, as its store files it; a satellite's is the machine's.
    package static func isMoonlight(_ connectionId: String) -> Bool {
        connectionId.hasPrefix(MoonlightHostStore.idPrefix)
    }

    /// One row per pooled or remembered satellite and per Moonlight host the
    /// pool or the records know, by name (an unnamed one by its address). A
    /// satellite's state folds the session's own with the "Needs pairing"
    /// marker and whether the last scan heard it:
    /// - `.live` → `.connected`; `.linking` → `.connecting`;
    /// - `.faltering`, and `.stale` while the silent retry is pending, →
    ///   `.unstable`, so the row does not flick to offline between the
    ///   heartbeat drop and the retry;
    /// - no session: marked stale → `.stale`; heard → `.ready`; else `.saved`.
    package var connections: [ConnectionSummary] {
        let rows = satelliteSummaries() + moonlightSummaries()
        return rows.sorted { ($0.recordName, $0.id) < ($1.recordName, $1.id) }
    }

    package func summary(_ id: String) -> ConnectionSummary? {
        connections.first { $0.id == id }
    }

    private func satelliteSummaries() -> [ConnectionSummary] {
        let pool = wifi.connections
        let remembered = Dictionary(wifi.remembered().map { ($0.id, $0) }) { first, _ in first }
        let discoveredIds = Set(wifi.discoveredServers.map(\.id))
        let staleIds = wifi.staleSatelliteIds
        let ids = Set(pool.keys).union(remembered.keys)
        return ids.compactMap { id -> ConnectionSummary? in
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
    }

    /// One row per Moonlight host in the pool or the records.
    private func moonlightSummaries() -> [ConnectionSummary] {
        guard let moonlight else { return [] }
        let records = Dictionary(moonlight.rememberedHosts.map { ($0.id, $0) }) { first, _ in first }
        let pool = moonlight.connections
        let discoveredIds = Set(moonlight.discoveredHosts.map(\.id))
        let ids = Set(pool.keys).union(records.keys)
        return ids.compactMap { id -> ConnectionSummary? in
            let conn = pool[id]
            guard let host = conn?.host ?? records[id]?.host else { return nil }
            return MoonlightDesire.summary(
                host: host,
                phase: conn?.phase ?? .idle,
                roundTripMs: conn?.controlRoundTripMs,
                paired: records[id]?.paired ?? false,
                verified: moonlight.verifiedHostIds.contains(id),
                discovered: discoveredIds.contains(id),
                boundSlotIds: bindings.filter { $0.value == id }.keys.sorted()
            )
        }
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
    /// carries four pads or is not in the pool. The slot's prior owner of
    /// either kind lets go. A satellite takes the pad on the lowest free
    /// index before the table publishes, so the pad's route already knows
    /// it: the pad's capabilities become the descriptor's claims, and its
    /// pick the catalog type it is emulated as. A Moonlight host's pad is
    /// composed by the app's converge; binding to a host is durable
    /// interest in it, remembered with the pick the host's record holds.
    @discardableResult
    func bind(slotId: String, connectionId: String, capabilities: ControllerCapabilities, emulateAs: EmulatedPad) -> Bool {
        let toHost = Self.isMoonlight(connectionId)
        guard toHost ? moonlight != nil : satelliteCanTake(connectionId, slotId: slotId) else { return false }
        if let prior = bindings[slotId], prior != connectionId {
            releaseSlot(slotId, from: prior)
        }
        if toHost {
            rememberOnHost(slotId: slotId, hostId: connectionId)
        } else {
            guard attachToSatellite(slotId: slotId, connectionId: connectionId, capabilities: capabilities, emulateAs: emulateAs) else {
                return false
            }
        }
        bindings[slotId] = connectionId
        return true
    }

    private func satelliteCanTake(_ connectionId: String, slotId: String) -> Bool {
        wifi.pooledConnection(id: connectionId) != nil && satelliteHasRoom(connectionId, for: slotId)
    }

    private func attachToSatellite(
        slotId: String,
        connectionId: String,
        capabilities: ControllerCapabilities,
        emulateAs: EmulatedPad
    ) -> Bool {
        guard let conn = wifi.pooledConnection(id: connectionId) else { return false }
        let type = wifi.resolveControllerType(for: connectionId, emulateAs: emulateAs)
        return conn.attachSlot(slotId, controllerType: type, capabilities: capabilities, emulateAs: emulateAs) != nil
    }

    /// The host is remembered as interest, and the binding with the type
    /// the host's own record picks, so a Forget names it.
    private func rememberOnHost(slotId: String, hostId: String) {
        guard let moonlight else { return }
        moonlight.rememberInterest(hostId: hostId)
        let hostType = Int(moonlight.rememberedEmulatedType(hostId: hostId))
        moonlight.rememberBinding(slotId: slotId, hostId: hostId, controllerType: hostType)
    }

    /// A satellite carries four pads; a slot it already carries rebinds in place.
    private func satelliteHasRoom(_ connectionId: String, for slotId: String) -> Bool {
        let others = bindings.filter { $0.value == connectionId && $0.key != slotId }.count
        return others < SatelliteSlots.maxPerSatellite
    }

    /// The slot's connection lets go of it: a satellite detaches that pad
    /// alone, a Moonlight host's pad leaves on the next converge.
    private func releaseSlot(_ slotId: String, from connectionId: String) {
        wifi.get(connectionId)?.detachSlot(slotId)
        moonlight?.forgetBinding(slotId: slotId)
    }

    /// The user let the pad go.
    func unbind(slotId: String) {
        release(slotId: slotId)
        moonlight?.forgetBinding(slotId: slotId)
    }

    /// The pad lets go: the user unbound it, it left, or its satellite
    /// refused it.
    func release(slotId: String) {
        guard let connectionId = bindings.removeValue(forKey: slotId) else { return }
        wifi.get(connectionId)?.detachSlot(slotId)
    }

    /// The pads attached now: a binding whose pad left is released.
    func keepPresent(_ present: Set<String>) {
        for slotId in bindings.keys where !present.contains(slotId) {
            release(slotId: slotId)
        }
    }

    /// Forget: every pad bound to the connection lets go, and so does every
    /// binding remembered for a host.
    func forgetBindings(of connectionId: String) {
        for (slotId, bound) in bindings where bound == connectionId {
            unbind(slotId: slotId)
        }
    }

    /// The pick for a bound slot: a live satellite binding re-sends that
    /// pad's descriptor with the new type; a Moonlight binding keeps the
    /// pick in its record and is re-announced by the app's converge.
    func setEmulatedType(slotId: String, _ pad: EmulatedPad) {
        guard let connectionId = bindings[slotId] else { return }
        if Self.isMoonlight(connectionId) {
            moonlight?.rememberBinding(slotId: slotId, hostId: connectionId, controllerType: Int(MoonlightDesire.controllerType(pad)))
            return
        }
        guard let conn = wifi.get(connectionId) else { return }
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
