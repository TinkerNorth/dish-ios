// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - The play screens

    var gamepad: String {
        catalog.text("Gamepad")
    }

    var mouse: String {
        catalog.text("Mouse")
    }

    var openGamepad: String {
        catalog.text("Open gamepad")
    }

    // MARK: - The mouse

    var mouseLeft: String {
        catalog.text("Left")
    }

    var mouseRight: String {
        catalog.text("Right")
    }

    var scroll: String {
        catalog.text("Scroll")
    }

    var mouseHint: String {
        catalog.text("Drag to move the pointer")
    }

    // MARK: - The touchpad

    var click: String {
        catalog.text("Click")
    }

    var touchpadHint: String {
        catalog.text("Use one or two fingers")
    }
}
