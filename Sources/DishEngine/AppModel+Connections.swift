// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// The Connections tab's facts and intents: the paired and found PCs from
/// the pool, each with where it stands and why the person's last attempt
/// on it failed, a scan, a connect, a reconnect, a graceful disconnect, a
/// Forget that self-unpairs, and a PC added by its address.
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

    /// What the last scan heard that is not paired, then the PCs typed by
    /// their address that the pool holds: each wants a PIN, or is being
    /// reached for.
    internal var foundFacts: [ConnectionFact] {
        let remembered = Set(network.wifi.remembered().map(\.id))
        let heard = network.wifi.discoveredServers
        let heardIds = Set(heard.map(\.id))
        let typed = network.wifi.connections.values.map(\.server)
            .filter { $0.source == .manual && !heardIds.contains($0.id) }
            .sorted { $0.id < $1.id }
        return (heard + typed).filter { !remembered.contains($0.id) }.map(foundFact)
    }

    private func foundFact(_ server: DiscoveredServer) -> ConnectionFact {
        let live = poolLive(server.id)
        return ConnectionFact(
            id: server.id,
            name: server.name,
            address: server.ip,
            kind: .satellite,
            state: foundState(live),
            notice: attemptNotice(attemptNotices.state[server.id], live: live)
        )
    }

    /// A found PC is being reached for while the pool reaches it, else it
    /// waits for a PIN.
    private func foundState(_ live: LinkState) -> ConnectionState {
        switch live {
        case .connecting: .connecting
        case .connected, .unstable, .stale, .saved, .ready: .needsPairing
        }
    }

    /// Where the pool's entry for a PC stands; one it never reached for rests.
    private func poolLive(_ id: String) -> LinkState {
        network.hub.summary(id)?.live ?? .saved
    }

    private func pairedFact(_ row: ConnectionSummary) -> ConnectionFact {
        let probe = network.wifi.capabilities[row.id]
        return ConnectionFact(
            id: row.id,
            name: row.name,
            address: row.address,
            kind: row.kind,
            state: connectionState(row),
            notice: attemptNotice(attemptNotices.state[row.id], live: row.live),
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
        case .connected: .online(latencyMs: wholeMilliseconds(row.latencyMs), controllers: row.boundSlotIds.count)
        case .unstable: .unsteady(latencyMs: wholeMilliseconds(row.latencyMs), controllers: row.boundSlotIds.count)
        case .connecting: .connecting
        case .stale: .needsPairing
        case .saved, .ready: .offline(lastSeen: network.wifi.store.lastSeen(row.id))
        }
    }

    /// The PC typed by its address: whether the pool reaches for it now, and
    /// what the attempt left.
    internal var addedByAddressFact: AddedByAddressFact? {
        guard let server = addedByAddress else { return nil }
        let live = poolLive(server.id)
        return AddedByAddressFact(
            id: server.id,
            reaching: live == .connecting,
            failure: attemptNotice(attemptNotices.state[server.id], live: live)
        )
    }

    // MARK: - What an attempt leaves

    internal func recordNotice(_ failure: ConnectionFailure, for id: String) {
        attemptNotices.updateState { $0.merging([id: failure]) { _, latest in latest } }
    }

    internal func clearNotice(_ id: String) {
        attemptNotices.updateState { $0.filter { $0.key != id } }
    }

    /// A PC whose session came up has nothing left to word.
    internal func clearNoticesOfLiveRows() {
        for conn in network.wifi.connections.values where conn.hasLiveSession {
            clearNotice(conn.id)
        }
    }

    /// The address sheet appearing: the last attempt's failure is not this one's.
    internal func clearAddedByAddressNotice() {
        guard let id = addedByAddress?.id else { return }
        clearNotice(id)
    }

    private func startReaching(_ id: String) {
        reaching.updateState { $0.union([id]) }
    }

    private func stopReaching(_ id: String) {
        reaching.updateState { $0.subtracting([id]) }
    }

    /// The PCs reached for are pruned as their links settle: Observation says
    /// a connection's state moved, and the set keeps the ones still linking.
    internal func followReaching() {
        withObservationTracking {
            _ = network.wifi.connections.values.map(\.state)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.reachingMoved() }
        }
    }

    private func reachingMoved() {
        let pool = network.wifi.connections
        reaching.updateState { ids in ids.filter { pool[$0]?.state == .linking } }
        followReaching()
    }

    // MARK: - Intents

    /// The person's own scan: it may raise iOS's Local Network question,
    /// which they asked for, so it needs no more explaining.
    func startScan() {
        onboarding.markLocalNetworkPrimed()
        localNetwork.scan()
    }

    /// The tab's opening scan, held back until the primer has explained the
    /// question it makes iOS ask.
    internal func scanIfPrimed() {
        guard onboarding.state.localNetworkPrimed else { return }
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
    /// satellite with no key answers with its pairing card. The attempt is
    /// the person's: its row reads connecting, the last attempt's failure
    /// goes, and a failure of this one is kept for the row.
    func connect(_ id: String) {
        guard let server = network.wifi.knownServer(id) else { return }
        clearNotice(id)
        startReaching(id)
        network.wifi.connect(to: server)
    }

    /// A row's Reconnect: a session that stopped answering closes and opens
    /// again; one that is down is reached for.
    func reconnect(_ id: String) {
        if network.hub.summary(id)?.live == .unstable { network.wifi.disconnect(id: id) }
        connect(id)
    }

    /// Close the session the graceful way, or stop reaching for the PC; the
    /// row and the key stay.
    func disconnect(_ id: String) {
        stopReaching(id)
        network.wifi.disconnect(id: id)
    }

    /// The satellite is told this iPhone unpaired itself, then every pad
    /// bound there lets go and the row, the key and the pin go.
    func forget(_ id: String) {
        stopReaching(id)
        clearNotice(id)
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
        clearNotice(server.id)
        addedByAddress = server
        startReaching(server.id)
        network.wifi.connect(to: server)
        return true
    }

    /// A satellite that wants a PIN opens its card; a failed attempt is kept
    /// for the PC's row; a scan's failure and a pairing's are already told
    /// by the page and the card.
    private func connectionEvent(_ event: ConnectionEvent) {
        switch event {
        case let .pairingRequired(server): beginPairing(server)
        case let .failure(serverId, failure): noteFailure(failure, of: serverId)
        case .scanFailed, .pairingFailed: break
        }
    }

    private func noteFailure(_ failure: ConnectionFailure, of id: String) {
        guard isRowNotice(failure) else { return }
        recordNotice(failure, for: id)
    }
}

/// Whether a failure is the PC's row to word: a controller the PC refused
/// is the apply's word on the pad's row, and a scan's failure is the page's.
func isRowNotice(_ failure: ConnectionFailure) -> Bool {
    switch failure {
    case .controllerNotApplied, .noServersFound, .localNetworkDenied: false
    case .identityChanged, .protocolMismatch, .dishUpdateRequired, .satelliteUpdateRequired, .approvalDeclined,
         .approvalTimedOut, .repairNeeded, .unreachable, .noSharedKey, .sessionRefused, .badSessionMaterial,
         .sessionLinkFailed, .pairingRejected: true
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
