// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - Settings tab

    var thisIPhone: String {
        catalog.text("This iPhone")
    }

    var nameOnYourPC: String {
        catalog.text("Name on your PC")
    }

    /// What iOS tells apps this device is called, and the name's placeholder.
    var iPhone: String {
        catalog.text("iPhone")
    }

    var deviceNameFooter: String {
        paragraph(
            catalog.text("iOS only tells apps “iPhone”."),
            catalog.text("Name it so Satellite can tell your devices apart.")
        )
    }

    var whileStreaming: String {
        catalog.text("While streaming")
    }

    var keepScreenOn: String {
        catalog.text("Keep screen on")
    }

    var dimScreenAfter: String {
        catalog.text("Dim screen after")
    }

    func seconds(_ count: Int) -> String {
        catalog.format("%lld s", count)
    }

    func minutes(_ count: Int) -> String {
        catalog.format("%lld min", count)
    }

    var never: String {
        catalog.text("Never")
    }

    var whileStreamingFooter: String {
        catalog.text("iOS pauses apps you leave, so Dish stays open and dims itself instead of locking.")
    }

    var setupAndHelp: String {
        catalog.text("Setup & help")
    }

    var setupGuide: String {
        catalog.text("Setup guide")
    }

    var appearance: String {
        catalog.text("Appearance")
    }

    var system: String {
        catalog.text("System")
    }

    var light: String {
        catalog.text("Light")
    }

    var dark: String {
        catalog.text("Dark")
    }

    var about: String {
        catalog.text("About")
    }

    var version: String {
        catalog.text("Version")
    }

    // MARK: - Steam Controllers

    var steamControllers: String {
        catalog.text("Steam Controllers")
    }

    var readOverBluetooth: String {
        catalog.text("Read over Bluetooth")
    }

    var steamBluetoothUnused: String {
        catalog.text("Dish doesn’t use Bluetooth until you turn this on.")
    }

    var steamBluetoothWaiting: String {
        catalog.text("Waiting for Bluetooth.")
    }

    var steamBluetoothReading: String {
        catalog.text("Reading the Steam Controllers paired in Settings › Bluetooth.")
    }

    var steamBluetoothPoweredOff: String {
        catalog.text("Bluetooth is turned off.")
    }

    var steamBluetoothRefused: String {
        paragraph(
            catalog.text("Dish isn’t allowed to use Bluetooth."),
            catalog.text("Allow it in Settings › Privacy & Security › Bluetooth.")
        )
    }

    var steamBluetoothRestricted: String {
        catalog.text("Bluetooth is restricted on this device.")
    }

    var steamBluetoothUnsupported: String {
        catalog.text("This device has no Bluetooth LE.")
    }

    var steamControllersFooter: String {
        paragraph(
            catalog.text("iOS doesn’t offer Steam Controllers to games, so Dish reads them over Bluetooth itself."),
            catalog.text("Turning this on asks for Bluetooth.")
        )
    }

    // MARK: - Name on your PC

    var deviceNamePageFooter: String {
        catalog.text("Your PC shows this name when Dish connects to it.")
    }
}
