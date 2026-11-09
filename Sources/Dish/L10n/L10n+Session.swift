// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - Session accessory

    var streaming: String {
        catalog.text("Streaming")
    }

    /// Plural: "1 pad", "3 pads".
    func padCount(_ pads: Int) -> String {
        catalog.format("%lld pads", pads)
    }

    /// A round trip, as the session line and a PC row show it.
    func latency(_ latencyMs: Int) -> String {
        catalog.format("%lld ms", latencyMs)
    }

    var stoppedResponding: String {
        catalog.text("Stopped responding")
    }

    var reconnect: String {
        catalog.text("Reconnect")
    }

    var dim: String {
        catalog.text("Dim")
    }

    var play: String {
        catalog.text("Play")
    }
}
