// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// How far one satellite's live link has progressed. The rows' `LinkState`
/// folds pairing and discovery in on top of this.
///
/// - `idle`: no session. `linking`: the handshake is in flight. `live`:
///   acks flowing. `faltering`: live, but the missed-ack count reached the
///   "not responding" threshold. `stale`: acks stopped while a key is still
///   held, and a silent retry is pending.
package enum SessionState: Equatable {
    case idle
    case linking
    case live
    case faltering
    case stale
}

/// The manager's policy callbacks, installed at `markConnected`. The
/// connection observes the wire and calls out; every decision lives in the
/// manager. All three fire on the main actor from the alive tick.
struct SessionHooks {
    /// Five consecutive missed acks.
    var onDead: @MainActor () -> Void = {}
    /// An authenticated close-notify reason byte, raw so an unknown future
    /// reason still routes.
    var onClose: @MainActor (UInt8) -> Void = { _ in }
    /// The enriched ack's epoch or bitmap drifted from the applied belief.
    var reconcile: @MainActor () -> Void = {}
}

/// One live or potential session to a satellite. Owns the UDP client while
/// live; topology rides REST through the manager, never UDP.
@MainActor
@Observable
package final class WifiConnection: Identifiable, FeedbackRouteTarget {

    package let id: String
    private(set) var server: DiscoveredServer
    package private(set) var state: SessionState = .idle
    /// The pads this session carries, each on its own controller index.
    private(set) var slotTable = SatelliteSlotTable()
    /// True while the manager's per-slot PUT or DELETE is in flight.
    private(set) var isRegisteringController = false
    /// The median heartbeat round trip halved, to 0.1 ms; nil until the first
    /// paired ack of the session.
    package private(set) var latencyOneWayMs: Double?
    private(set) var latencySamples = 0
    private(set) var connectionId: String?
    /// The live client, which every bound pad's route holds.
    package private(set) var client: SatelliteClient?
    /// What the last negotiation said about the satellite's version.
    private(set) var protocolCompat: ProtocolCompat = .unknown
    /// The version the live session speaks; the floor while no session.
    private(set) var settledProtocolVersion = ProtocolConstants.protocolVersionMin
    /// The version the next pairing or session PUT offers. A 409 whose range
    /// still overlaps ours lowers it, and the lowered offer sticks.
    private(set) var offeredProtocolVersion = ProtocolConstants.protocolVersion

    @ObservationIgnored private(set) var lastHeartbeatAck: HeartbeatAck?
    /// The epoch of the topology last applied; -1 while no session.
    @ObservationIgnored private(set) var lastAppliedEpoch = -1
    /// Set when the manager's reconcile GET launches, cleared when it lands.
    @ObservationIgnored private(set) var reconcileInFlight = false
    /// The controller indices whose descriptor changed while live and wait
    /// for the manager's per-slot PUT or DELETE.
    @ObservationIgnored private var pendingIndices: Set<Int> = []
    /// A bound slot changed while live; the manager converges over REST.
    @ObservationIgnored var onTopologyChanged: (@MainActor () -> Void)?
    /// The send counter crossed the re-key threshold; fires once per approach.
    @ObservationIgnored var onRekeyNeeded: (@MainActor () -> Void)?
    /// Observational relay of a parsed close reason; policy rides the hooks.
    @ObservationIgnored var onSessionClose: (@MainActor (CloseReason) -> Void)?
    /// The live client came or went: the pads' routes hold it.
    @ObservationIgnored var onClientChanged: (@MainActor () -> Void)?
    /// The router's routes for this connection's indices, kept for a
    /// reconnect's fresh client.
    @ObservationIgnored var feedbackRoutes: FeedbackRoutes?
    @ObservationIgnored private var hooks = SessionHooks()
    @ObservationIgnored private let tickIntervalNs: UInt64
    @ObservationIgnored private var aliveTask: Task<Void, Never>?
    @ObservationIgnored private var rekeyRequested = false

    init(id: String, server: DiscoveredServer, tickIntervalNs: UInt64 = 1_000_000_000) {
        self.id = id
        self.server = server
        self.tickIntervalNs = tickIntervalNs
    }

    package static func idFor(_ server: DiscoveredServer) -> String {
        server.id
    }

    /// Linking, live or faltering: a connect must not restart this.
    var hasSession: Bool {
        state == .live || state == .linking || state == .faltering
    }

    /// Live or faltering: REST may be healthy while UDP acks are lossy, so
    /// converges, re-keys and reconciles still run.
    var hasLiveSession: Bool {
        state == .live || state == .faltering
    }

    func updateServer(_ server: DiscoveredServer) {
        if server != self.server { self.server = server }
    }

    func markConnecting() {
        if hasLiveSession { return }
        state = .linking
    }

    // MARK: - The pads

    /// Every edit of the pads lands here, published once: each index whose
    /// descriptor the edit changed converges while live.
    @discardableResult
    func editSlots<Result>(_ edit: (inout SatelliteSlotTable) -> Result) -> Result {
        let before = slotTable.descriptorsByIndex()
        var table = slotTable
        let result = edit(&table)
        if table != slotTable { slotTable = table }
        convergeIndices(changedIndices(before, table.descriptorsByIndex()))
        return result
    }

    /// Queue the indices for the manager's per-slot routes; nothing while no
    /// session, whose next PUT carries the whole set.
    func convergeIndices(_ indices: Set<Int>) {
        guard hasLiveSession, !indices.isEmpty else { return }
        pendingIndices.formUnion(indices)
        onTopologyChanged?()
    }

    /// The indices waiting for the manager, handed over once.
    func takePendingIndices() -> Set<Int> {
        let taken = pendingIndices
        pendingIndices = []
        return taken
    }

    // MARK: - Protocol version

    func setOfferedProtocolVersion(_ version: Int) {
        offeredProtocolVersion = version
    }

    /// The PUT settled: the frames key off this, and the chip follows.
    func adoptProtocol(_ outcome: ProtocolOutcome) {
        settledProtocolVersion = outcome.settledVersion
        protocolCompat = compatForOutcome(outcome)
    }

    /// A terminal 409: the row keeps saying which end must update.
    func setProtocolCompat(_ compat: ProtocolCompat) {
        protocolCompat = compat
    }

    // MARK: - Session lifecycle

    /// Go live: start the receive loop, the heartbeat and the alive tick.
    /// `epoch` is the PUT response's epoch, the reconcile baseline.
    func markConnected(client: SatelliteClient, connectionId: String, epoch: Int, hooks: SessionHooks) {
        guard state == .linking else { return }
        self.client = client
        self.connectionId = connectionId
        self.hooks = hooks
        state = .live
        lastHeartbeatAck = nil
        lastAppliedEpoch = epoch
        reconcileInFlight = false
        rekeyRequested = false
        latencyOneWayMs = nil
        latencySamples = 0
        installClientHandlers(client)
        client.startReceiveLoop()
        client.startHeartbeat()
        startAliveTick()
        onClientChanged?()
        convergeIndices(slotTable.unappliedIndices)
    }

    private func installClientHandlers(_ client: SatelliteClient) {
        client.setFeedbackRoutes(feedbackRoutes)
        client.setSessionCloseHandler { [weak self] reason in
            Task { @MainActor [weak self] in self?.onSessionClose?(reason) }
        }
    }

    private func startAliveTick() {
        let interval = tickIntervalNs
        aliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled, let self else { return }
                if self.aliveTick() == .sessionEnded { return }
            }
        }
    }

    enum TickOutcome {
        case running
        case sessionEnded
    }

    /// One alive poll: a latched close first, then death, then the live and
    /// faltering flip, then the readouts and the drift check.
    @discardableResult
    func aliveTick() -> TickOutcome {
        guard let live = client else {
            hooks.onDead()
            return .sessionEnded
        }
        tickSnapshotsAndRekey(live)
        let closeReason = live.sessionCloseReason.get()
        if closeReason >= 0 {
            hooks.onClose(UInt8(truncatingIfNeeded: closeReason))
            return .sessionEnded
        }
        guard live.connectionAlive.get() else {
            hooks.onDead()
            return .sessionEnded
        }
        flipLiveOrFaltering(live)
        publishLatency(live)
        evaluateReconcile()
        return .running
    }

    private func flipLiveOrFaltering(_ live: SatelliteClient) {
        let faltering = live.missedAcks.get() >= ProtocolConstants.heartbeatMissNotResponding
        let want: SessionState = faltering ? .faltering : .live
        if state != want, hasLiveSession {
            state = want
        }
    }

    /// Written only when the displayed figure moved, so the tick does not
    /// churn observers.
    private func publishLatency(_ live: SatelliteClient) {
        let snapshot = live.latencySnapshot()
        let rounded = snapshot.p50OneWayMs.map { ($0 * 10).rounded() / 10 }
        if rounded != latencyOneWayMs { latencyOneWayMs = rounded }
        if snapshot.samples != latencySamples { latencySamples = snapshot.samples }
    }

    private func evaluateReconcile() {
        guard !reconcileInFlight, let ack = lastHeartbeatAck else { return }
        let drifted = reconcileNeeded(
            serverEpoch: Int(ack.epoch),
            serverBitmap: Int(ack.bitmap),
            lastAppliedEpoch: lastAppliedEpoch,
            expectedBitmap: expectedBitmap(slotTable.appliedSlots())
        )
        if drifted {
            hooks.reconcile()
        }
    }

    private func tickSnapshotsAndRekey(_ live: SatelliteClient) {
        lastHeartbeatAck = live.heartbeatAckSnapshot()
        let needsRekey = counterNeedsRepush(live.sendCounter)
        if needsRekey, !rekeyRequested {
            rekeyRequested = true
            onRekeyNeeded?()
        }
        if !needsRekey {
            rekeyRequested = false
        }
    }

    func markDisconnected() {
        teardown(parkedOn: .idle)
    }

    /// Death-path teardown: the row reads unstable through the backoff
    /// window instead of flicking straight to offline.
    func parkStaleAwaitingRetry() {
        teardown(parkedOn: .stale)
    }

    private func teardown(parkedOn endState: SessionState) {
        let existing = client
        let nothingToTearDown = state == .idle && existing == nil && endState == .idle
        if nothingToTearDown { return }
        aliveTask?.cancel()
        aliveTask = nil
        isRegisteringController = false
        existing?.closeSocket()
        client = nil
        connectionId = nil
        lastHeartbeatAck = nil
        lastAppliedEpoch = -1
        reconcileInFlight = false
        pendingIndices = []
        slotTable.clearApplied()
        hooks = SessionHooks()
        latencyOneWayMs = nil
        latencySamples = 0
        state = endState
        if existing != nil { onClientChanged?() }
    }

    // MARK: - Reconcile state

    func setLastAppliedEpoch(_ epoch: Int) {
        lastAppliedEpoch = epoch
    }

    func setReconcileInFlight(_ inFlight: Bool) {
        reconcileInFlight = inFlight
    }

    func setSlotSyncInFlight(_ inFlight: Bool) {
        isRegisteringController = inFlight
    }
}
