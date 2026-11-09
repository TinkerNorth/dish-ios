// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - The low-power dim

    var lowPower: String {
        catalog.text("Low power")
    }

    var tapToWake: String {
        catalog.text("Tap to wake")
    }

    var dimFootnote: String {
        paragraph(
            catalog.text("Streaming continues while dimmed."),
            catalog.text("Keep Dish open: iOS pauses apps you leave.")
        )
    }
}
