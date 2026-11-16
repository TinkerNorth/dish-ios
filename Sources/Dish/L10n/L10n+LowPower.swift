// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - The low-power countdown, and the pad's ways to a PC and to the phone's screens

    /// The accessory's line while the last seconds run.
    func lowPowerIn(_ seconds: Int) -> String {
        catalog.format("Low power in %lld s", seconds)
    }

    /// A pad with no PC to bind to: the way to the Connections tab.
    var findAPC: String {
        catalog.text("Find a PC")
    }

    var openTouchpad: String {
        catalog.text("Open touchpad")
    }

    var openMouse: String {
        catalog.text("Open mouse")
    }
}
