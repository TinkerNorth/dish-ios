// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - Connections tab

    var paired: String {
        catalog.text("Paired")
    }

    var foundOnYourWiFi: String {
        catalog.text("Found on your Wi‑Fi")
    }

    var searching: String {
        catalog.text("Searching")
    }

    var online: String {
        catalog.text("Online")
    }

    /// Plural: "1 controller", "3 controllers".
    func controllerCount(_ controllers: Int) -> String {
        catalog.format("%lld controllers", controllers)
    }

    var offline: String {
        catalog.text("Offline")
    }

    /// `when` is a relative date the mapper words ("yesterday").
    func offlineSeen(_ when: String) -> String {
        catalog.format("Offline · seen %@", when)
    }

    func needsPairingAt(_ address: String) -> String {
        catalog.format("Needs pairing · %@", address)
    }

    var moonlightHosts: String {
        catalog.text("Moonlight hosts")
    }

    var moonlightHostsHint: String {
        catalog.text("Sunshine, Apollo or Wolf. Input only.")
    }

    var connectionsFootnote: String {
        paragraph(
            catalog.text("Satellite is the fastest path."),
            catalog.text("A Moonlight host works without installing anything new, at a little more latency.")
        )
    }

    var noPCsYet: String {
        catalog.text("No PCs yet")
    }

    var noPCsYetBody: String {
        catalog.text("Run Satellite on a PC on this Wi‑Fi and it shows up here.")
    }

    var cantSeeYourNetwork: String {
        catalog.text("Dish can’t see your network")
    }

    var cantSeeYourNetworkBody: String {
        paragraph(
            catalog.text("Local Network is off for Dish, so it can’t find Satellite or send input to your PC."),
            catalog.text("Turn it on and Dish picks up where it left off.")
        )
    }

    var openSettings: String {
        catalog.text("Open Settings")
    }

    var localNetworkSettingsPath: String {
        catalog.text("Settings › Dish › Local Network")
    }
}
