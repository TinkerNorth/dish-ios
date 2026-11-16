// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - The Lightning note, wherever a wired pad is offered

    var lightningPort: String {
        catalog.text("Lightning port")
    }

    var wiredNeedsTheAdapter: String {
        catalog.text("A wired controller needs Apple’s Lightning to USB Camera Adapter.")
    }

    var whatYouNeed: String {
        catalog.text("What you need")
    }

    /// The chip on setup's wired row, and the label under the adapter drawn.
    var adapter: String {
        catalog.text("Adapter")
    }

    /// Setup's wired row on a Lightning iPhone, in place of the USB-C port.
    var wiredThroughTheAdapterBody: String {
        paragraph(catalog.text("Through Apple’s Lightning to USB Camera Adapter."), catalog.text("Lowest latency."))
    }

    /// The link word of a pad attached to a Lightning iPhone.
    var linkLightning: String {
        catalog.text("Lightning")
    }

    // MARK: - The Wired on this iPhone sheet

    var wiredOnThisIPhone: String {
        catalog.text("Wired on this iPhone")
    }

    var thisIPhoneHasALightningPort: String {
        catalog.text("This iPhone has a Lightning port.")
    }

    var aLightningCableCannotCarryAPad: String {
        catalog.text("A Lightning cable alone can’t carry a controller’s input.")
    }

    var plugTheAdapterIn: String {
        catalog.text("Plug the adapter into the iPhone’s Lightning port.")
    }

    var plugTheControllerIntoTheAdapter: String {
        catalog.text("Plug the controller’s USB cable into the adapter.")
    }

    var powerTheAdapter: String {
        paragraph(
            catalog.text("Pick the USB 3 adapter and plug a charger into its Lightning port."),
            catalog.text("A controller draws more power than the iPhone gives on its own.")
        )
    }

    var bluetoothNeedsNoAdapter: String {
        catalog.text("Bluetooth needs no adapter.")
    }

    var applesAdapter: String {
        catalog.text("Apple’s Lightning to USB 3 Camera Adapter")
    }

    // MARK: - Help & FAQ and the hint on a Lightning iPhone

    var wiredControllerDoesntShowUp: String {
        catalog.text("My wired controller doesn’t show up.")
    }

    var wiredControllerDoesntShowUpAnswer: String {
        paragraph(
            thisIPhoneHasALightningPort,
            aLightningCableCannotCarryAPad,
            catalog.text("Plug it in through the adapter, or pair it over Bluetooth.")
        )
    }

    /// Add a controller's hint on a Lightning iPhone: the wired road runs
    /// through the adapter.
    var pairYourPadThroughTheAdapterHintMessage: String {
        paragraph(
            catalog.text("Apps can’t pair Bluetooth devices, so Dish leaves that to iOS."),
            catalog.text("Pair it in Settings › Bluetooth first, or plug it in through Apple’s camera adapter.")
        )
    }
}
