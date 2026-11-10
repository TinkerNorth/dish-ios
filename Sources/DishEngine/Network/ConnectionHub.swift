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
    /// The satellite bindings kept across restarts; a Moonlight host's live
    /// in its manager's store.
    @ObservationIgnored private let memory: BindingMemoryStore
    /// The pads whose standing binding was already tried while they stay
    /// attached, so a refused one is not retried by every change.
    @ObservationIgnored private var restoreTried: Set<String> = []

    package init(wifi: WifiConnectionManager, moonlight: MoonlightConnectionManager? = nil) {
        self.wifi = wifi
        self.moonlight = moonlight
        memory = wifi.store.bindingMemory
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
    /// interest in it. Every binding is remembered across restarts, one
    /// record per pad of one kind; `pick` is the pad's own, nil while it
    /// follows its family.
    @discardableResult
    func bind(
        slotId: String,
        connectionId: String,
        capabilities: ControllerCapabilities,
        emulateAs: EmulatedPad,
        pick: EmulatedPad? = nil
    ) -> Bool {
        let toHost = Self.isMoonlight(connectionId)
        guard toHost ? moonlight != nil : satelliteCanTake(connectionId, slotId: slotId) else { return false }
        if let prior = bindings[slotId], prior != connectionId {
            releaseSlot(slotId, from: prior)
        }
        if toHost {
            rememberOnHost(slotId: slotId, hostId: connectionId, pick: pick)
        } else {
            guard attachToSatellite(slotId: slotId, connectionId: connectionId, capabilities: capabilities, emulateAs: emulateAs) else {
                return false
            }
            rememberOnSatellite(slotId: slotId, satelliteId: connectionId)
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
    /// its record already holds for this pad on this host, else the pad's
    /// own pick, else the host's own, so a restart finds both.
    private func rememberOnHost(slotId: String, hostId: String, pick: EmulatedPad?) {
        memory.forget(slotId: slotId)
        guard let moonlight else { return }
        moonlight.rememberInterest(hostId: hostId)
        let held = moonlight.rememberedBindings.first { $0.slotId == slotId && $0.hostId == hostId }
        let hostType = Int(moonlight.rememberedEmulatedType(hostId: hostId))
        let type = held?.controllerType ?? pick.map { Int(MoonlightDesire.controllerType($0)) } ?? hostType
        moonlight.rememberBinding(slotId: slotId, hostId: hostId, controllerType: type)
    }

    /// One record per pad, of one kind: a satellite's in `wifi_binding_list`,
    /// a host's in `moonlight_binding_list`, so a pad that moved between the
    /// kinds is never restored to both.
    private func rememberOnSatellite(slotId: String, satelliteId: String) {
        memory.remember(RememberedSatelliteBinding(slotId: slotId, satelliteId: satelliteId))
        moonlight?.forgetBinding(slotId: slotId)
    }

    /// A satellite carries four pads; a slot it already carries rebinds in place.
    private func satelliteHasRoom(_ connectionId: String, for slotId: String) -> Bool {
        let others = bindings.filter { $0.value == connectionId && $0.key != slotId }.count
        return others < SatelliteSlots.maxPerSatellite
    }

    /// The slot's connection lets go of it: a satellite detaches that pad
    /// alone and its motion word goes, a Moonlight host's pad leaves on the
    /// next converge.
    private func releaseSlot(_ slotId: String, from connectionId: String) {
        wifi.get(connectionId)?.detachSlot(slotId)
        wifi.motionStatus.clear(SlotKey(connectionId: connectionId, slotId: slotId))
    }

    /// The user let the pad go: the binding and its memory both end.
    func unbind(slotId: String) {
        release(slotId: slotId)
        memory.forget(slotId: slotId)
        moonlight?.forgetBinding(slotId: slotId)
    }

    /// The pad lets go: it left, or its satellite refused it, and its memory
    /// stays for its return; the user's unbind ends the memory too.
    func release(slotId: String) {
        guard let connectionId = bindings.removeValue(forKey: slotId) else { return }
        releaseSlot(slotId, from: connectionId)
    }

    /// The pads attached now: a binding whose pad left is released, its
    /// memory kept, and its standing binding is due again when the pad returns.
    func keepPresent(_ present: Set<String>) {
        restoreTried.formIntersection(present)
        for slotId in bindings.keys where !present.contains(slotId) {
            release(slotId: slotId)
        }
    }

    /// Forget: every pad bound to the connection lets go, and so does every
    /// binding remembered for it, whether or not its pad is here.
    func forgetBindings(of connectionId: String) {
        for (slotId, bound) in bindings where bound == connectionId {
            unbind(slotId: slotId)
        }
        memory.forgetSatellite(connectionId)
        for record in moonlight?.rememberedBindings ?? [] where record.hostId == connectionId {
            moonlight?.forgetBinding(slotId: record.slotId)
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

    /// The pick for a pad bound to a Moonlight host, in the protocol's own
    /// numbering; nil returns the pad to the host's own type. It is kept
    /// with the pad's binding and reaches the host on the next converge.
    func setMoonlightEmulatedType(slotId: String, _ type: Int?) {
        guard let connectionId = bindings[slotId], Self.isMoonlight(connectionId), let moonlight else { return }
        let hostType = Int(moonlight.rememberedEmulatedType(hostId: connectionId))
        moonlight.rememberBinding(slotId: slotId, hostId: connectionId, controllerType: type ?? hostType)
    }

    /// What a pad on a Moonlight host is emulated as: the type its binding
    /// holds, a pick of its own only where it differs from the host's. Nil
    /// for a pad bound to a satellite or to none.
    func hostEmulation(slotId: String) -> HostEmulationFact? {
        guard let connectionId = bindings[slotId], Self.isMoonlight(connectionId), let moonlight else { return nil }
        let hostType = Int(moonlight.rememberedEmulatedType(hostId: connectionId))
        let held = moonlight.rememberedBindings.first { $0.slotId == slotId && $0.hostId == connectionId }
        let type = held.map { Int(MoonlightPadRules.migrateStoredType($0.controllerType)) } ?? hostType
        return HostEmulationFact(type: type, isOverride: type != hostType)
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

// MARK: - Memory across restarts

/// A binding remembered from an earlier run, due to be bound again: the pad
/// and its destination. The pick is the pad's own, or the host's record's.
struct StandingBinding: Equatable {
    let slotId: String
    let connectionId: String
}

extension ConnectionHub {

    /// The remembered bindings to bind now: each of a pad present and unbound
    /// whose destination is known here (a satellite pooled or remembered, a
    /// host on record), each tried once while its pad stays attached. A pad
    /// that left is tried again when it returns.
    func takeDueStandingBindings(present: Set<String>, satellites: Set<String>, hosts: Set<String>) -> [StandingBinding] {
        restoreTried.formIntersection(present)
        let known = satellites.union(hosts)
        let due = standingBindings().filter { standing in
            let waiting = present.contains(standing.slotId) && bindings[standing.slotId] == nil
            return waiting && !restoreTried.contains(standing.slotId) && known.contains(standing.connectionId)
        }
        restoreTried.formUnion(due.map(\.slotId))
        return due
    }

    /// Every remembered binding, of both kinds.
    private func standingBindings() -> [StandingBinding] {
        let satellites = memory.bindings().map { StandingBinding(slotId: $0.slotId, connectionId: $0.satelliteId) }
        let hosts = (moonlight?.rememberedBindings ?? []).map { StandingBinding(slotId: $0.slotId, connectionId: $0.hostId) }
        return satellites + hosts
    }
}
