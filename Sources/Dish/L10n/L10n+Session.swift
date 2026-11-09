// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - Session accessory

    func streamingPadsLatency(_ pads: Int, _ latencyMs: Int) -> String {
        catalog.format("Streaming · %lld pads · %lld ms", pads, latencyMs)
    }

    func streamingPads(_ pads: Int) -> String {
        catalog.format("Streaming · %lld pads", pads)
    }

    func padsLatency(_ pads: Int, _ latencyMs: Int) -> String {
        catalog.format("%lld pads · %lld ms", pads, latencyMs)
    }

    func pads(_ pads: Int) -> String {
        catalog.format("%lld pads", pads)
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
