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

    /// Beside the list on an iPad, where a pull does not reach the refresh.
    var scan: String {
        catalog.text("Scan")
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

    // MARK: - A row's button and a PC's page

    var pair: String {
        catalog.text("Pair")
    }

    var connect: String {
        catalog.text("Connect")
    }

    var disconnect: String {
        catalog.text("Disconnect")
    }

    var repair: String {
        catalog.text("Re-pair")
    }

    var forgetThisPC: String {
        catalog.text("Forget This PC")
    }

    var forget: String {
        catalog.text("Forget")
    }

    var pairingKeyIsDeleted: String {
        catalog.text("Its pairing key is deleted.")
    }

    /// Plural: "1 controller stops streaming", "3 controllers stop streaming".
    func controllersStopStreaming(_ controllers: Int) -> String {
        catalog.format("%lld controllers stop streaming, and you’ll need the PIN again.", controllers)
    }

    var youNeedThePinAgain: String {
        catalog.text("You’ll need the PIN again.")
    }

    var carrying: String {
        catalog.text("Carrying")
    }

    /// "2 of 4": the controllers a PC carries of the four it can.
    func countOf(_ count: Int, _ limit: Int) -> String {
        catalog.format("%lld of %lld", count, limit)
    }

    /// The index a controller holds on the PC, counted from one.
    func slot(_ index: Int) -> String {
        catalog.format("Slot %lld", index)
    }

    var nothingBoundYet: String {
        catalog.text("Nothing bound yet")
    }

    func satelliteVersion(_ version: String) -> String {
        catalog.format("Satellite %@", version)
    }

    func protocolVersion(_ version: Int) -> String {
        catalog.format("Protocol %lld", version)
    }

    var pcNoLongerRemembered: String {
        catalog.text("This PC is no longer remembered.")
    }

    /// A PC page's title while its PC is gone.
    var pc: String {
        catalog.text("PC")
    }
}
