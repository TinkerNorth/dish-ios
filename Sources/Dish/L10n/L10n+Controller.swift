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

    // MARK: - The Motion row

    var motionNoGyroscope: String {
        catalog.text("Motion: no gyroscope")
    }

    var motionTurnedOff: String {
        catalog.text("Motion: turned off")
    }

    var motionNotSent: String {
        catalog.text("Motion: not sent")
    }

    var motionHostCannotReceive: String {
        catalog.text("Motion: host can’t receive")
    }

    var motionServerCannotDeliver: String {
        catalog.text("Motion: server can’t deliver")
    }

    var motionStreaming: String {
        catalog.text("Motion: streaming")
    }

    var noPadAudio: String {
        catalog.text("Microphone and controller speaker aren’t open to apps on iOS, so Dish leaves them out.")
    }

    // MARK: - Binding

    var unbind: String {
        catalog.text("Unbind")
    }

    var bindTo: String {
        catalog.text("Bind to")
    }

    var pairAPCToBind: String {
        catalog.text("Pair a PC on the Connections tab to bind this controller.")
    }

    var applyingBinding: String {
        catalog.text("Applying binding…")
    }

    var bindingApplied: String {
        catalog.text("Binding applied")
    }

    var pcRefusedTheController: String {
        catalog.text("The PC refused the controller.")
    }

    var pcDidNotAnswer: String {
        catalog.text("The PC didn’t answer in time.")
    }

    var controllerLeftBeforeApplied: String {
        catalog.text("The controller left before the binding was applied.")
    }

    var bindingCancelled: String {
        catalog.text("Binding cancelled.")
    }
}
