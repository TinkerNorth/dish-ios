// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - A controller's page

    /// The page's title while its pad is away, and a pad of no known family.
    var controller: String {
        catalog.text("Controller")
    }

    func batteryLevel(_ percent: Int) -> String {
        catalog.format("%lld%% battery", percent)
    }

    var controllerGone: String {
        catalog.text("This controller isn’t connected to your iPhone.")
    }

    var nintendo: String {
        catalog.text("Nintendo")
    }

    var binding: String {
        catalog.text("Binding")
    }

    var destination: String {
        catalog.text("Destination")
    }

    var functions: String {
        catalog.text("Functions")
    }

    var adaptiveTriggers: String {
        catalog.text("Adaptive triggers")
    }

    var playerLeds: String {
        catalog.text("Player LEDs")
    }

    var noPadAudio: String {
        catalog.text("Microphone and controller speaker aren’t open to apps on iOS, so Dish leaves them out.")
    }
}
