// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// The Connections tab's facts and intents: the paired and found PCs from
/// the pool, a scan, a connect, a graceful disconnect, a Forget that
/// self-unpairs, and a PC added by its address.
package extension AppModel {

    /// The pool's signals reach the model: an event is kept for the pages and
    /// a satellite that wants a PIN opens its card; a refused slot lets its
    /// binding go; a client or pool change moves the pads' routes; and the
    /// remembered satellites are reached for at once.
    internal func wireNetwork() {
        let wifi = network.wifi
        wifi.onEvent = { [weak self] event in self?.connectionEvent(event) }
        wifi.onSlotRegistrationFailed = { [weak self] slotId in self?.slotRefused(slotId) }
        wifi.onSlotApplied = { [weak self] connectionId, slotId in self?.slotConfirmed(connectionId: connectionId, slotId: slotId) }
        wifi.onClientChanged = { [weak self] in self?.clientChanged() }
        wifi.onPoolChanged = { [weak self] in self?.refreshRouting() }
        followAttachedPads()
        wifi.autoReconnectAll()
    }

    /// Every remembered satellite, in name order.
    internal var pairedFacts: [ConnectionFact] {
        let remembered = Set(network.wifi.remembered().map(\.id))
        return network.hub.connections.filter { remembered.contains($0.id) }.map(pairedFact)
    }

    /// What the last scan heard that is not paired: each wants a PIN.
    internal var foundFacts: [ConnectionFact] {
        let remembered = Set(network.wifi.remembered().map(\.id))
        return network.wifi.discoveredServers.filter { !remembered.contains($0.id) }.map { server in
            ConnectionFact(id: server.id, name: server.name, address: server.ip, kind: .satellite, state: .needsPairing)
        }
    }

    private func pairedFact(_ row: ConnectionSummary) -> ConnectionFact {
        let probe = network.wifi.capabilities[row.id]
        return ConnectionFact(
            id: row.id,
            name: row.name,
            address: row.address,
            kind: row.kind,
            state: connectionState(row),
            boundControllerIds: row.boundSlotIds,
            satelliteVersion: probe.flatMap(satelliteVersion),
            protocolVersion: sessionProtocolVersion(row),
            features: probe.map { SatelliteFeaturesFact(motion: $0.motionAvailable, rumble: $0.host.rumble.available) }
        )
    }

    /// The version a live session speaks; nil while none is up.
    private func sessionProtocolVersion(_ row: ConnectionSummary) -> Int? {
        guard sessionIsUp(row.live) else { return nil }
        return network.wifi.get(row.id)?.settledProtocolVersion
    }

    private func connectionState(_ row: ConnectionSummary) -> ConnectionState {
        switch row.live {
        case .connected, .unstable: .online(latencyMs: wholeMilliseconds(row.latencyMs), controllers: row.boundSlotIds.count)
        case .stale: .needsPairing
        case .saved, .ready, .connecting: .offline(lastSeen: network.wifi.store.lastSeen(row.id))
        }
    }

    // MARK: - Intents

    /// The person's own scan: it may raise iOS's Local Network question.
    func startScan() {
        localNetwork.scan()
    }

    /// Pull to refresh on Connections: the person's own scan, and the wait
    /// until discovery has adopted it, so the spinner stays while it looks.
    func refreshConnections() async {
        startScan()
        while network.wifi.isScanning {
            await nextScanningChange()
        }
    }

    /// Returns once the manager's scanning flag next changes. Observation
    /// calls before the change lands; the caller reads the flag again.
    private func nextScanningChange() async {
        let wifi = network.wifi
        await withCheckedContinuation { continuation in
            // The read registers the observation; the loop reads the flag itself.
            _ = withObservationTracking { wifi.isScanning } onChange: { continuation.resume() }
        }
    }

    /// Connect a paired or found satellite at its freshest known address; a
    /// satellite with no key answers with its pairing card.
    func connect(_ id: String) {
        guard let server = network.wifi.knownServer(id) else { return }
        network.wifi.connect(to: server)
    }

    /// Close the session the graceful way; the row and the key stay.
    func disconnect(_ id: String) {
        network.wifi.disconnect(id: id)
    }

    /// The satellite is told this iPhone unpaired itself, then every pad
    /// bound there lets go and the row, the key and the pin go.
    func forget(_ id: String) {
        network.hub.forgetBindings(of: id)
        network.wifi.forget(id: id)
        refreshRouting()
    }

    /// A PC typed by its IPv4 address, optionally `:port`: the connect probes
    /// it and opens its pairing card, and setup's Bind and Review know it as
    /// the PC added by address. The attempt starts with no stale failure to
    /// word. False when the text is not an address.
    @discardableResult
    func addByAddress(_ text: String) -> Bool {
        guard let server = DiscoveredServer.manual(from: text) else { return false }
        lastConnectionEvent = nil
        addedByAddress = server
        network.wifi.connect(to: server)
        return true
    }

    private func connectionEvent(_ event: ConnectionEvent) {
        lastConnectionEvent = event
        guard case let .pairingRequired(server) = event else { return }
        beginPairing(server)
    }
}

/// A latency figure in whole milliseconds; zero until measured.
func wholeMilliseconds(_ latencyMs: Double?) -> Int {
    latencyMs.map { Int($0.rounded()) } ?? 0
}

/// The satellite's own version string; nil for one that reports none.
func satelliteVersion(_ probe: ServerCapabilitiesDTO) -> String? {
    probe.serverVersion.isEmpty ? nil : probe.serverVersion
}
