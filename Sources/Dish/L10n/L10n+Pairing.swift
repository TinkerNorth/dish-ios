// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - The pair sheet

    func pairWith(_ name: String) -> String {
        catalog.format("Pair with %@", name)
    }

    var enterThePinSatelliteShows: String {
        catalog.text("Enter the PIN Satellite shows on your PC.")
    }

    var currentPinPath: String {
        catalog.text("Satellite › Pairing › Current PIN")
    }

    var orWord: String {
        catalog.text("or")
    }

    var acceptOnYourPC: String {
        catalog.text("Accept on your PC")
    }

    func satelliteShowsARequestFrom(_ device: String) -> String {
        catalog.format("Satellite shows a request from %@.", device)
    }

    var acceptItIfTheCodeMatches: String {
        catalog.text("Accept it if the code matches.")
    }

    var waiting: String {
        catalog.text("Waiting")
    }

    func requestExpiresIn(_ minutes: Int) -> String {
        catalog.format("The request expires in %lld min.", minutes)
    }

    var approvedConnecting: String {
        catalog.text("Approved, connecting")
    }

    var operatorDeclined: String {
        catalog.text("The operator declined the pairing.")
    }

    var codeExpired: String {
        catalog.text("The code expired before your PC answered.")
    }

    var identityChanged: String {
        catalog.text("This satellite's security identity changed. If it was reinstalled, forget it here and pair again.")
    }

    func differentSatelliteVersion(_ name: String) -> String {
        catalog.format("%@ is running a different Satellite version. Update both, then pair again.", name)
    }

    func couldNotReach(_ name: String) -> String {
        catalog.format("Couldn’t reach %@. Make sure it’s on and on your network.", name)
    }

    func notApprovedYet(_ name: String) -> String {
        catalog.format("%@ hasn’t approved the pairing yet.", name)
    }

    func pinNotAccepted(_ name: String) -> String {
        catalog.format("That PIN wasn’t accepted. Check the code on %@ and try again.", name)
    }

    var codeChangesOnRefresh: String {
        catalog.text("The code changes if the Satellite screen was refreshed.")
    }

    var renameThisIPhone: String {
        catalog.text("Rename this iPhone")
    }

    var done: String {
        catalog.text("Done")
    }

    var cancel: String {
        catalog.text("Cancel")
    }

    // MARK: - Add a PC by address

    var enterThePCsAddress: String {
        paragraph(
            catalog.text("Enter the PC’s IPv4 address."),
            catalog.text("Add a port after a colon when Satellite uses another.")
        )
    }

    /// The field's example, an address every network has one of.
    var addressExample: String {
        catalog.text("192.168.1.50")
    }

    /// `port` is the satellite's default data-plane port, as digits.
    func dishUsesPort(_ port: String) -> String {
        catalog.format("Dish uses port %@ unless you add another.", port)
    }

    var invalidAddress: String {
        catalog.text("Enter an IPv4 address like 192.168.1.50 (optionally :port)")
    }

    // MARK: - A connection's failures

    var repairNeeded: String {
        catalog.text("This satellite no longer recognizes this device. Re-pair needed.")
    }

    var linkWouldNotOpen: String {
        catalog.text("The satellite accepted, but the controller link would not open. Try again.")
    }

    var dishUpdateRequired: String {
        catalog.text("Dish update required")
    }

    var satelliteUpdateRequired: String {
        catalog.text("Satellite update required")
    }
}
