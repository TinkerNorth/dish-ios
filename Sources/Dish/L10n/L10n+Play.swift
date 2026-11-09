// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - The play screens and the pause menu

    var pause: String {
        catalog.text("Pause")
    }

    var resume: String {
        catalog.text("Resume")
    }

    var gamepad: String {
        catalog.text("Gamepad")
    }

    var mouse: String {
        catalog.text("Mouse")
    }

    var stopGamepad: String {
        catalog.text("Stop gamepad")
    }

    var motionNeedsDualSense: String {
        catalog.text("Needs DualSense emulation")
    }

    var motionNeedsSensors: String {
        catalog.text("This iPhone has no motion sensors")
    }

    var open: String {
        catalog.text("Open")
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
