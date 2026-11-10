// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - TipKit's hints

    /// The heart's: what Support Dish is.
    var supportDishHintMessage: String {
        paragraph(
            catalog.text("Dish is free and open source."),
            catalog.text("Every feature stays free, tip or not.")
        )
    }

    /// Add a controller's: pads pair in Settings, not in Dish.
    var pairYourPadHintMessage: String {
        paragraph(
            catalog.text("Apps can’t pair Bluetooth devices, so Dish leaves that to iOS."),
            catalog.text("Pair it in Settings › Bluetooth first, or plug it in.")
        )
    }

    /// The pause button's: the way out of play.
    var leaveThroughThePauseMenu: String {
        catalog.text("Leave through the pause menu")
    }

    var stopGamepadTakesYouBack: String {
        catalog.text("Stop gamepad in this menu takes you back to Dish.")
    }

    /// The session accessory's Dim.
    var dimTheScreenWhileYouPlay: String {
        catalog.text("Dim the screen while you play")
    }

    var dimHintMessage: String {
        paragraph(
            catalog.text("Streaming continues while dimmed."),
            catalog.text("Tap the dimmed screen to wake it, and set the delay in Settings › Dim screen after.")
        )
    }
}
