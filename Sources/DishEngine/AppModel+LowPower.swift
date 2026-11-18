// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import Observation

/// The low-power countdown's intents and what arms it: the screen held on
/// (`screenHeld`), while the dim is not already up.
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

    /// Follows the session, the settings and the shell's leave.
    internal func observeLowPower() {
        withObservationTracking {
            _ = sessionFact
            _ = streaming.state.dimAfter
            _ = streaming.state.keepScreenOn
            _ = dimAllowed.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.lowPowerInputsMoved() }
        }
    }

    private func lowPowerInputsMoved() {
        syncLowPower()
        observeLowPower()
    }

    /// The count runs exactly while Dish holds the screen on.
    private func syncLowPower() {
        let held = screenHeld(session: sessionFact, keepScreenOn: streaming.state.keepScreenOn)
        lowPower.arm(streaming.state.dimAfter, while: held && dimAllowed.state)
    }
}
