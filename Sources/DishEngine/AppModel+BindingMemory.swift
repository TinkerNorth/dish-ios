// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// Bindings survive a restart, as the desktops' standing bindings and
/// Android's Moonlight ones do: a remembered binding is bound again without
/// the user once its pad is attached (the on-screen gamepad once it is
/// listed) and its destination is known here (a satellite pooled or
/// remembered, a Moonlight host on record), whichever comes last.
extension AppModel {

    /// Watches the pads, the pool, the satellites and hosts on record and
    /// the on-screen gamepad's listing; the change is settled by the time
    /// the task runs, so what it reads is the new state.
    func observeBindingMemory() {
        withObservationTracking {
            _ = pads.source.slots
            _ = network.wifi.connections
            _ = network.wifi.rememberedServers
            _ = network.moonlight.rememberedHosts
            _ = onScreenListed.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.standingBindingsMoved() }
        }
    }

    private func standingBindingsMoved() {
        restoreStandingBindings()
        observeBindingMemory()
    }

    func restoreStandingBindings() {
        let due = network.hub.takeDueStandingBindings(
            present: presentSlotIds,
            satellites: Set(network.wifi.connections.keys).union(network.wifi.rememberedServers.map(\.id)),
            hosts: Set(network.moonlight.rememberedHosts.map(\.id))
        )
        for standing in due {
            bind(slotId: standing.slotId, to: standing.connectionId)
        }
    }
}
