// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import Observation

/// The low-power countdown's intents and what arms it.
package extension AppModel {

    /// A touch on the phone, anywhere.
    func touched() {
        lowPower.touched()
    }

    /// Whether the shell could raise the dim now.
    func setDimAllowed(_ allowed: Bool) {
        dimAllowed.setState(allowed)
        syncLowPower()
    }

    /// The shell took the due countdown.
    func lowPowerHandled() {
        lowPower.handled()
    }

    /// Follows the session, the delay setting and the shell's leave.
    internal func observeLowPower() {
        withObservationTracking {
            _ = sessionFact
            _ = streaming.state.dimAfter
            _ = dimAllowed.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.lowPowerInputsMoved() }
        }
    }

    private func lowPowerInputsMoved() {
        syncLowPower()
        observeLowPower()
    }

    private func syncLowPower() {
        lowPower.arm(streaming.state.dimAfter, while: sessionFact != nil && dimAllowed.state)
    }
}
