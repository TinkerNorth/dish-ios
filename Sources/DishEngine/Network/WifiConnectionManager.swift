// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import CryptoKit
import DishCore
import Foundation
import Observation
import os
import Synchronization

/// What the manager tells the app: a satellite that wants a PIN, or a failure
/// the user may need to hear about.
package enum ConnectionEvent: Equatable {
    case pairingRequired(DiscoveredServer)
    case failure(ConnectionFailure)
    /// A pairing attempt's failure, which the pairing card for that satellite
    /// shows itself.
    case pairingFailed(serverId: String, failure: ConnectionFailure)
}

/// Hosts whose presented TLS certificate mismatched the stored TOFU pin. The
/// pin verifier records on URLSession's delegate queue; the manager consumes
/// on the main actor, so a mismatch surfaces as an identity problem rather
/// than as "unreachable".
final class PinMismatchLog: Sendable {
    private let hosts = Mutex<Set<String>>([])

    func record(_ host: String) {
        hosts.withLock { hosts in hosts.formUnion([host]) }
    }

    /// True, and the breadcrumb cleared, when `host` mismatched since the
    /// last consume.
    func consume(_ host: String) -> Bool {
        hosts.withLock { $0.remove(host) != nil }
    }
}

/// Who asked for a connect. Only a user-initiated attempt may surface a
/// failure; the automatic ones report through the row's state alone.
enum ConnectIntent {
    case userInitiated
    case autoReconnect
    case retryAfterDeath
}

/// Owns the pool of live and remembered satellite sessions. Each session runs
/// its own socket, heartbeat and alive tick, so several satellites stream in
/// parallel. The pairing, approval, session, slots, discovery and lifecycle
/// flows live in the extensions of those names.
@MainActor
@Observable
package final class WifiConnectionManager {

    package private(set) var connections: [String: WifiConnection] = [:]
    package private(set) var discoveredServers: [DiscoveredServer] = []
    package private(set) var isScanning = false
    /// Whether iOS held the last scan on the Local Network policy; nil
    /// before any scan finished.
    package private(set) var localNetworkDenied: Bool?
    /// Ids in the pair-and-handshake flow; the rows show a spinner.
    package private(set) var pairingInFlight: Set<String> = []
    /// Satellites that revoked this device's key, or never had one, and so
    /// read "Needs pairing" until a user-initiated pair succeeds.
    package private(set) var staleSatelliteIds: Set<String> = []
    /// The store's rows, mirrored so a change re-derives the rows.
    package private(set) var rememberedServers: [RememberedWifi] = []
    /// Each satellite's pairing as the card shows it.
    package let pairingAttempts = PairingAttempts()

    /// A satellite that wants a PIN, or a failure; the app's to show.
    @ObservationIgnored var onEvent: (@MainActor (ConnectionEvent) -> Void)?
    /// The slot the satellite refused to plug, so the hub rolls it back.
    @ObservationIgnored var onSlotRegistrationFailed: (@MainActor (String) -> Void)?
    /// The satellite confirmed a slot plugged: connection id, slot id.
    @ObservationIgnored var onSlotApplied: (@MainActor (String, String) -> Void)?
    /// A connection's live client came or went: the pads' routes follow.
    @ObservationIgnored var onClientChanged: (@MainActor () -> Void)?
    /// A connection joined or left the pool: the return paths follow.
    @ObservationIgnored var onPoolChanged: (@MainActor () -> Void)?

    nonisolated static let discoveryLog = Logger(subsystem: "com.tinkernorth.dish.ios", category: "discovery")

    @ObservationIgnored let store: ConnectionStore
    /// Path-B approval poll cadence; tests shrink it.
    @ObservationIgnored let approvalPolling: ApprovalPolling
    /// The LAN's discovery as one call; tests script a LAN.
    @ObservationIgnored let discovery: DiscoveryPaths
    /// The name the satellite shows for this iPhone, read at each request.
    @ObservationIgnored let deviceName: @MainActor () -> String
    @ObservationIgnored let now: @MainActor () -> Date
    @ObservationIgnored let tickIntervalNs: UInt64
    @ObservationIgnored lazy var deviceId = store.getOrCreateDeviceId()
    @ObservationIgnored let pinMismatches = PinMismatchLog()
    @ObservationIgnored lazy var pairing = PairingClient(pinVerifier: makePinVerifier())
    @ObservationIgnored lazy var http = HTTPClient(pinVerifier: makePinVerifier())
    /// In-flight path-B approval polls by connection id, so a re-issued
    /// request supersedes the prior poll and forget or disconnect cancels it.
    @ObservationIgnored var approvalPolls: [String: Task<Void, Never>] = [:]
    /// In-flight path-A PIN submissions by connection id, so an approval
    /// landing first can stop the one it beat.
    @ObservationIgnored var pinSubmissions: [String: Task<Void, Never>] = [:]
    /// Per-connection reconnect throttle on the backoff curve.
    @ObservationIgnored var retry: [String: RetryState] = [:]
    @ObservationIgnored var retryTasks: [String: Task<Void, Never>] = [:]
    /// Per-satellite client catalog, read before the first session PUT.
    @ObservationIgnored var catalogs: [String: CatalogDTO] = [:]
    /// Per-satellite capabilities probe, read before the first session PUT.
    @ObservationIgnored var capabilities: [String: ServerCapabilitiesDTO] = [:]
    /// Depth-counted so a superseded approval flow unwinding after its
    /// cancellation cannot clear the marker its successor holds.
    @ObservationIgnored private var pairingDepth: [String: Int] = [:]

    package init(
        store: ConnectionStore,
        deviceName: @escaping @MainActor () -> String,
        approvalPolling: ApprovalPolling = .standard,
        discovery: DiscoveryPaths = .live,
        now: @escaping @MainActor () -> Date = Date.init,
        tickIntervalNs: UInt64 = 1_000_000_000
    ) {
        self.store = store
        self.deviceName = deviceName
        self.approvalPolling = approvalPolling
        self.discovery = discovery
        self.now = now
        self.tickIntervalNs = tickIntervalNs
        rememberedServers = store.remembered()
    }

    func emit(_ event: ConnectionEvent) {
        onEvent?(event)
    }

    func refreshRemembered() {
        let rows = store.remembered()
        if rows != rememberedServers { rememberedServers = rows }
    }

    // MARK: - Pairing-in-flight marker

    func beginPairing(_ id: String) {
        pairingDepth[id, default: 0] += 1
        pairingInFlight.insert(id)
    }

    func endPairing(_ id: String) {
        let depth = (pairingDepth[id] ?? 1) - 1
        if depth > 0 {
            pairingDepth[id] = depth
        } else {
            pairingDepth.removeValue(forKey: id)
            pairingInFlight.remove(id)
        }
    }

    // MARK: - Trust

    /// First contact pins the certificate's SHA-256 fingerprint for the host;
    /// a later certificate that differs is refused and breadcrumbed. Runs on
    /// URLSession's delegate queue, over the store's locked pins.
    func makePinVerifier() -> PinVerifier {
        let pins = store.pins
        let mismatches = pinMismatches
        return { host, der in
            let presented = sha256FingerprintHex(der)
            switch tofuVerdict(pinned: pins.pin(host: host), presented: presented) {
            case .trustFirstUse:
                pins.setPin(host: host, fingerprintHex: presented)
                return true
            case .match:
                return true
            case .mismatch:
                mismatches.record(host)
                return false
            }
        }
    }

    func get(_ id: String) -> WifiConnection? {
        connections[id]
    }

    // MARK: - Pool

    /// Insert `conn` into the pool and wire its signals: slot changes
    /// converge over REST, a send counter near exhaustion re-keys the
    /// session, and a client that comes or goes moves the pads' routes.
    func register(_ conn: WifiConnection) {
        connections[conn.id] = conn
        conn.onTopologyChanged = { [weak self, weak conn] in
            guard let self, let conn else { return }
            Task { await self.syncSlots(conn) }
        }
        conn.onRekeyNeeded = { [weak self, weak conn] in
            guard let self, let conn else { return }
            Task { await self.rekeySession(conn) }
        }
        conn.onClientChanged = { [weak self] in self?.clientChanged() }
        onPoolChanged?()
    }

    private func clientChanged() {
        onClientChanged?()
    }

    /// The pool entry for `server`, created and registered on first use.
    func pooledConnection(for server: DiscoveredServer) -> WifiConnection {
        let id = WifiConnection.idFor(server)
        if let existing = connections[id] { return existing }
        let fresh = WifiConnection(id: id, server: server, tickIntervalNs: tickIntervalNs)
        register(fresh)
        return fresh
    }

    /// The pool entry for a satellite known by id, made from its freshest
    /// record on first use: the pool's, then the scan's, then the store's.
    func pooledConnection(id: String) -> WifiConnection? {
        if let pooled = connections[id] { return pooled }
        return knownServer(id).map(pooledConnection(for:))
    }

    /// The freshest record of a satellite: the pooled connection's, then the
    /// scan's, then the remembered one.
    package func knownServer(_ id: String) -> DiscoveredServer? {
        let pooled = connections[id]?.server
        let discovered = discoveredServers.first { $0.id == id }
        let remembered = rememberedServers.first { $0.id == id }?.toDiscovered()
        return pooled ?? discovered ?? remembered
    }

    // MARK: - Scan state (written here; the discovery flow lives in its extension)

    /// True when a scan may start; a second request while one runs is dropped.
    func markScanStarted() -> Bool {
        if isScanning { return false }
        isScanning = true
        return true
    }

    func publishScan(_ servers: [DiscoveredServer], localNetworkDenied denied: Bool) {
        if servers != discoveredServers { discoveredServers = servers }
        if localNetworkDenied != denied { localNetworkDenied = denied }
        isScanning = false
    }

    // MARK: - Stale markers

    func markStale(_ id: String) {
        if !staleSatelliteIds.contains(id) {
            staleSatelliteIds.insert(id)
        }
    }

    func clearStale(_ id: String) {
        if staleSatelliteIds.contains(id) {
            staleSatelliteIds.remove(id)
        }
    }

    // MARK: - Connect / disconnect / forget

    /// Idempotent: a second call while live or linking only refreshes the
    /// server record. A user action resets the backoff curve and lifts the
    /// replaced-session suppression.
    func connect(to server: DiscoveredServer, intent: ConnectIntent = .userInitiated) {
        let id = WifiConnection.idFor(server)
        if intent == .userInitiated { clearRetry(id) }
        if let existing = connections[id], existing.hasSession {
            existing.updateServer(server)
            return
        }
        let conn = pooledConnection(for: server)
        conn.updateServer(server)
        conn.markConnecting()
        Task { await pairAndConnect(conn: conn, server: server, intent: intent) }
    }

    /// A failure is surfaced only for an attempt the user made; automatic
    /// attempts report through the row's state.
    func emitFailureIfUserInitiated(_ intent: ConnectIntent, _ failure: ConnectionFailure) {
        if intent == .userInitiated {
            emit(.failure(failure))
        }
    }

    /// Graceful close: `DELETE /api/connections/{id}`. The row and the key
    /// survive, and no scheduled retry resurrects a session the user closed.
    func disconnect(id: String) {
        guard let conn = connections[id] else { return }
        dropPairing(id)
        let server = conn.server
        let connectionId = conn.connectionId
        let did = deviceId
        let proof = proofFor(id)
        if conn.hasLiveSession { store.markSeen(id, at: now()) }
        conn.markDisconnected()
        clearRetry(id)
        guard let connectionId else { return }
        let http = http
        Task.detached(priority: .utility) {
            await http.deleteSession(ip: server.ip, port: server.httpPort, connectionId: connectionId, deviceId: did, hmacProof: proof)
        }
    }

    /// Forget self-unpairs on the satellite (`DELETE /api/pair`) before the
    /// key is dropped, because the proof needs the key; then the row, the
    /// key, the pin, the catalog and every retry marker go.
    func forget(id: String) {
        dropPairing(id)
        selfUnpair(id)
        disconnect(id: id)
        store.forget(id)
        refreshRemembered()
        connections.removeValue(forKey: id)
        catalogs.removeValue(forKey: id)
        capabilities.removeValue(forKey: id)
        clearStale(id)
        clearRetry(id)
        onPoolChanged?()
    }

    private func selfUnpair(_ id: String) {
        let proof = proofFor(id)
        guard let endpoint = rememberedEndpoint(id), !proof.isEmpty else { return }
        let did = deviceId
        let http = http
        Task.detached(priority: .utility) {
            await http.unpair(ip: endpoint.ip, port: endpoint.httpPort, deviceId: did, hmacProof: proof)
        }
    }

    private func rememberedEndpoint(_ id: String) -> (ip: String, httpPort: Int)? {
        if let pooled = connections[id] {
            return (pooled.server.ip, pooled.server.httpPort)
        }
        return store.remembered().first { $0.id == id }.map { ($0.ip, $0.httpPort) }
    }

    // MARK: - Auth material

    /// The stored pairing key as raw bytes, or nil when absent or malformed.
    func pairingKeyData(for id: String) -> Data? {
        guard let hex = store.sharedKey(for: id), hex.count == 64,
              let data = hexToBytes(hex), data.count == 32 else { return nil }
        return data
    }

    /// The `X-Hmac-Proof` header value; empty when no key is stored.
    func proofFor(_ id: String) -> String {
        guard let key = pairingKeyData(for: id) else { return "" }
        return SessionCrypto.hmacProofHex(pairingKey: key, deviceId: deviceId)
    }

    /// The one funnel for every trust revocation (a terminal 401, a
    /// close-notify with the `unpaired` reason): drop only the key, park the
    /// row on "Needs pairing", tear the session and stop the retry curve.
    func handleTerminalAuth(_ id: String, loud: Bool) {
        store.forgetKey(for: id)
        markStale(id)
        clearRetry(id)
        connections[id]?.markDisconnected()
        if loud {
            emit(.failure(.repairNeeded))
        }
    }

    // MARK: - Reconnect sweeps

    /// Reconnect every remembered satellite that is resting and whose retry
    /// is due. Silent by intent.
    func autoReconnectAll() {
        let nowMs = Self.nowMs()
        for remembered in store.remembered() where isResting(remembered.id) {
            if let throttle = retry[remembered.id], throttle.suppressed || nowMs < throttle.nextRetryAtMs {
                continue
            }
            connect(to: remembered.toDiscovered(), intent: .autoReconnect)
        }
    }

    private func isResting(_ id: String) -> Bool {
        guard let existing = connections[id] else { return true }
        return existing.state == .idle || existing.state == .stale
    }

    /// The app is leaving the foreground: every session closes the graceful
    /// way and its row rests, so the return's reconnect is its next attempt.
    func closeSessionsForBackground() {
        let open = connections.values.filter(\.hasSession).map(\.id)
        for id in open.sorted() {
            disconnect(id: id)
        }
    }

    /// Back in the foreground: sockets may be dead and addresses moved, so
    /// resting rows reconnect now instead of waiting out the backoff curve.
    /// Suppressed rows (a session the satellite replaced) stay parked.
    func resumeInForeground() {
        for (id, state) in retry where !state.suppressed {
            clearRetry(id)
        }
        autoReconnectAll()
    }

    package func remembered() -> [RememberedWifi] {
        rememberedServers
    }
}
