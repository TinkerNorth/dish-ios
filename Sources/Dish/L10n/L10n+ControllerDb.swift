// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The controller database: Settings' switch and Check now in the website
/// privacy policy's words, Diagnostics' lines and the report's mail note,
/// and a controller's record on its page and its card.
extension L10n {

    // MARK: - Settings

    var controllerDatabase: String {
        catalog.text("Controller database")
    }

    /// The privacy policy's label for the switch, word for word.
    var checkForControllerUpdatesAutomatically: String {
        catalog.text("Check for controller updates automatically")
    }

    /// The privacy policy's label for the action, word for word.
    var checkNow: String {
        catalog.text("Check now")
    }

    var checking: String {
        catalog.text("Checking…")
    }

    var controllerDatabaseFooter: String {
        paragraph(
            catalog.text("Dish asks dish.tinkernorth.com for a newer list of the controllers it knows."),
            catalog.text("It fetches data, never code, and sends nothing about you.")
        )
    }

    func databaseVersionBuiltIn(_ version: Int) -> String {
        catalog.format("Version %lld, built in", version)
    }

    func databaseVersionDownloaded(_ version: Int) -> String {
        catalog.format("Version %lld, downloaded", version)
    }

    // MARK: - The last check

    var checkUpToDate: String {
        catalog.text("Up to date")
    }

    var checkUpdated: String {
        catalog.text("Updated")
    }

    var checkOffline: String {
        catalog.text("No connection")
    }

    var checkInvalid: String {
        catalog.text("The download did not verify")
    }

    var checkOff: String {
        catalog.text("Checks are off")
    }

    var notCheckedYet: String {
        catalog.text("Not checked yet")
    }

    // MARK: - Diagnostics

    var builtInVersion: String {
        catalog.text("Built-in version")
    }

    var lastCheck: String {
        catalog.text("Last check")
    }

    /// The mail's one sentence under the summary: what the file holds and
    /// what it never holds.
    var diagnosticsAttachmentNote: String {
        catalog.text("The file holds this page and its log, never pairing keys, fingerprints, IP addresses, Wi-Fi names or PC names.")
    }

    // MARK: - A controller's record

    /// The language the database's own strings are read in: the one the
    /// catalog speaks.
    var databaseLocale: String {
        catalog.locale.identifier
    }

    var recordName: String {
        catalog.text("Name")
    }

    var record: String {
        catalog.text("Record")
    }

    var verification: String {
        catalog.text("Verification")
    }

    var knownIssue: String {
        catalog.text("Known issue")
    }

    var verified: String {
        catalog.text("Verified")
    }

    var imported: String {
        catalog.text("Imported")
    }

    var reportedByPlayers: String {
        catalog.text("Reported by players")
    }

    var layoutGuessed: String {
        catalog.text("Layout guessed")
    }

    var problemsReported: String {
        catalog.text("Problems reported")
    }

    var notInTheDatabase: String {
        catalog.text("Not in the controller database")
    }
}
