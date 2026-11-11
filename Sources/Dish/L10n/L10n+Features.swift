// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - Settings › Forwarded features

    var forwardedFeatures: String {
        catalog.text("Forwarded features")
    }

    var motionDetail: String {
        catalog.text("Forward gyroscope and accelerometer to the host, used for motion aiming in games that support it.")
    }

    var rumbleDetail: String {
        catalog.text("Play vibration the host game sends back on your controller.")
    }

    var touchpadDetail: String {
        catalog.text("Forward the DualSense / DualShock 4 touchpad. Controllers without a touchpad ignore this.")
    }

    var lightbarDetail: String {
        catalog.text("Follow game: the controller LED matches the host game. Off: leave the LED untouched.")
    }

    var featuresFootnote: String {
        catalog.text("Features only apply when your controller's hardware supports them. The controller list shows what was detected.")
    }

    var followGame: String {
        catalog.text("Follow game")
    }

    var off: String {
        catalog.text("Off")
    }
}
