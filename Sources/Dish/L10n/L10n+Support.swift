// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Support Dish: tips through the App Store. The prices are StoreKit's own
/// localized strings and never a key.
extension L10n {

    var supportDish: String {
        catalog.text("Support Dish")
    }

    var supportPitch: String {
        paragraph(
            catalog.text("Dish is free and open source."),
            catalog.text("A tip pays for the time that goes into Dish and Satellite."),
            catalog.text("Every feature stays free, tip or not.")
        )
    }

    var tips: String {
        catalog.text("Tips")
    }

    var smallTip: String {
        catalog.text("Small tip")
    }

    var mediumTip: String {
        catalog.text("Medium tip")
    }

    var largeTip: String {
        catalog.text("Large tip")
    }

    var loading: String {
        catalog.text("Loading")
    }

    var tipsUnavailable: String {
        catalog.text("Tips aren’t available right now.")
    }

    var tryAgain: String {
        catalog.text("Try again")
    }

    var thankYou: String {
        catalog.text("Thank you")
    }

    var thankYouBody: String {
        catalog.text("Your tip keeps Dish free for everyone.")
    }

    var tipPending: String {
        catalog.text("Your tip is waiting for approval.")
    }

    var tipFailed: String {
        catalog.text("The App Store couldn’t complete the tip.")
    }

    var nothingToRestore: String {
        catalog.text("There’s no tip to restore.")
    }

    var restorePurchases: String {
        catalog.text("Restore purchases")
    }

    var supportFootnote: String {
        paragraph(
            catalog.text("The App Store handles the payment."),
            catalog.text("Dish never sees your card.")
        )
    }
}
