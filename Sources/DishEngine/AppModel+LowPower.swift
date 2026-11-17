// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import Observation

/// The low-power countdown's intents and what arms it: a session that
/// streams with a pad bound, while the shell could raise the dim.
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
        lowPower.arm(streaming.state.dimAfter, while: lowPowerWanted(sessionFact) && dimAllowed.state)
    }
}

/// The screen saves power only while there is something to save it for: a
/// session streaming with a pad bound. One being brought back, one that
/// stopped responding or failed, and one carrying no pad leave the screen
/// alone, so the person sees what is happening.
func lowPowerWanted(_ session: SessionFact?) -> Bool {
    guard let session else { return false }
    switch session.phase {
    case .streaming: return session.pads > 0
    case .stoppedResponding, .reconnecting, .failed: return false
    }
}
