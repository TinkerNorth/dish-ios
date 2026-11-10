// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// The bind in flight: which pad on which satellite, and the budget that
/// ends it when the satellite never answers.
struct ApplyWatch {
    let slotId: String
    let connectionId: String
    let budget: Task<Void, Never>
}

/// How long an apply waits for the satellite before it reads unreachable.
let applyBudgetNs: UInt64 = 15_000_000_000

/// Binding a pad to a satellite: the binding, the pick and the switches go
/// out with the session PUT (or the per-slot PUT while live), and the apply
/// follows the satellite until it carries the pad, refuses it, or the
/// budget runs out. Each bound pad's feed gets its route from here, set when
/// the satellite's session comes up and cleared when it goes down.
package extension AppModel {

    /// Bind the pad to the satellite. A satellite with no session is reached
    /// for; the bind rides its session PUT.
    func bind(slotId: String, to connectionId: String) {
        guard let slot = pads.source.slots.first(where: { $0.id == slotId }) else { return advanceApply(.padGone) }
        let path: ApplyPath = sessionIsUp(network.hub.summary(connectionId)?.live) ? .hostLive : .waitingForLink
        endApplyWatch()
        let pick = pads.types.typeFor(slotId) ?? slot.family.emulatedPad
        let bound = network.hub.bind(slotId: slotId, connectionId: connectionId, capabilities: slot.capabilities, emulateAs: pick)
        advanceApply(.started(path))
        guard bound else { return advanceApply(.hostRejected) }
        watchApply(slotId: slotId, connectionId: connectionId)
        refreshRouting()
        if path == .waitingForLink { reachFor(connectionId) }
    }

    /// The pad lets go of its satellite; its route clears.
    func unbind(slotId: String) {
        network.hub.release(slotId: slotId)
        refreshRouting()
    }

    /// The apply's overlay went away.
    func dismissApply() {
        advanceApply(.dismissed)
    }

    /// The PC the controller is bound to and how it is answering; nil while
    /// unbound.
    internal func destination(slotId: String) -> DestinationFact? {
        guard let row = network.hub.boundConnection(slotId: slotId) else { return nil }
        return DestinationFact(name: row.name, health: linkHealth(row.live))
    }

    // MARK: - Routes

    /// One snapshot from the bindings and the live clients: every bound pad
    /// on a live satellite gets that client as its sink under the index it
    /// holds, the return paths get the same table, and each connection's
    /// descriptors take the pads' switches.
    internal func refreshRouting() {
        let snapshot = currentRoutingSnapshot()
        routing.publish(snapshot, to: pads.source.processor)
        returnPaths.wire(network.wifi.connections.mapValues { $0 as any FeedbackRouteTarget })
        returnPaths.route(snapshot, global: pads.features.flags)
        pushSlotFlags()
    }

    private func currentRoutingSnapshot() -> RoutingSnapshot {
        var snapshot = RoutingSnapshot()
        for (slotId, connectionId) in network.hub.bindings {
            guard let conn = network.wifi.get(connectionId), let index = conn.controllerIndex(of: slotId) else { continue }
            let flags = forwardingFlags(slotId: slotId)
            if let client = conn.client {
                snapshot.bySlot[slotId] = Route(sink: client, slot: SlotIndex(index), flags: flags)
            }
            let pad = SatellitePadKey(connectionId: connectionId, controllerIndex: index)
            snapshot.bySatellitePad[pad] = BoundSlotRoute(slotId: slotId, flags: flags)
        }
        return snapshot
    }

    private func pushSlotFlags() {
        for conn in network.wifi.connections.values {
            let flags = Dictionary(uniqueKeysWithValues: conn.boundSlotIds.map { ($0, forwardingFlags(slotId: $0)) })
            conn.setSlotFlags(flags)
        }
    }

    /// The pads iOS lists move: a binding whose pad left lets go, and an
    /// apply waiting on it ends.
    internal func followAttachedPads() {
        withObservationTracking {
            _ = pads.source.slots
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.attachedPadsChanged() }
        }
    }

    private func attachedPadsChanged() {
        let present = Set(pads.source.slots.map(\.id))
        network.hub.keepPresent(present)
        if let watch = applyWatch, !present.contains(watch.slotId) { advanceApply(.padGone) }
        refreshRouting()
        followAttachedPads()
    }

    // MARK: - Following the satellite

    internal func clientChanged() {
        refreshRouting()
        guard let watch = applyWatch, sessionIsUp(network.hub.summary(watch.connectionId)?.live) else { return }
        advanceApply(.putSent)
    }

    internal func slotConfirmed(connectionId: String, slotId: String) {
        guard let watch = applyWatch, watch.slotId == slotId, watch.connectionId == connectionId else { return }
        advanceApply(.hostConfirmed)
    }

    internal func slotRefused(_ slotId: String) {
        network.hub.release(slotId: slotId)
        refreshRouting()
        guard applyWatch?.slotId == slotId else { return }
        advanceApply(.hostRejected)
    }

    private func watchApply(slotId: String, connectionId: String) {
        let budget = Task { [weak self] in
            try? await Task.sleep(nanoseconds: applyBudgetNs)
            guard !Task.isCancelled else { return }
            self?.advanceApply(.budgetSpent)
        }
        applyWatch = ApplyWatch(slotId: slotId, connectionId: connectionId, budget: budget)
    }

    private func endApplyWatch() {
        applyWatch?.budget.cancel()
        applyWatch = nil
    }

    private func reachFor(_ connectionId: String) {
        guard network.hub.summary(connectionId)?.live != .connecting else { return }
        connect(connectionId)
    }

    internal func advanceApply(_ event: ApplyEvent) {
        let before = bindingProgress
        let next = reduceApply(before, event)
        if next != before { bindingProgress = next }
        if applyInFlight(before), !applyInFlight(next) { endApplyWatch() }
    }
}

/// A session is up while it is live or faltering.
func sessionIsUp(_ live: LinkState?) -> Bool {
    switch live {
    case .connected, .unstable: true
    case .stale, .saved, .ready, .connecting, nil: false
    }
}

/// How the PC a controller is bound to is answering.
func linkHealth(_ live: LinkState) -> LinkHealth {
    switch live {
    case .connected: .online
    case .unstable, .connecting: .unsteady
    case .stale, .saved, .ready: .lost
    }
}
