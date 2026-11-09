// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - Controllers tab

    var addAController: String {
        catalog.text("Add a controller")
    }

    var addAControllerHint: String {
        catalog.text("Wired, Bluetooth, or on-screen.")
    }

    var noControllersInvitation: String {
        catalog.text("Bind a pad or the on-screen gamepad to your PC to start playing.")
    }

    var connectionLost: String {
        catalog.text("Connection lost")
    }

    var unsteady: String {
        catalog.text("Unsteady")
    }

    var notBound: String {
        catalog.text("Not bound")
    }

    var linkUsbC: String {
        catalog.text("USB-C")
    }

    var linkBluetooth: String {
        catalog.text("Bluetooth")
    }

    var linkOnScreen: String {
        catalog.text("On-screen")
    }

    func batteryPercent(_ percent: Int) -> String {
        catalog.format("%lld%%", percent)
    }
}
