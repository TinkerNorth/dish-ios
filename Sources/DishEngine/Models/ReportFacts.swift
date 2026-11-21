// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What the person filled in on Report a problem: the category, their own
/// words, and the controller it concerns, by its slot id.
package struct ReportDraft: Equatable {
    package let category: ReportCategory
    package let text: String
    package let controllerId: String?

    package init(category: ReportCategory, text: String, controllerId: String?) {
        self.category = category
        self.text = text
        self.controllerId = controllerId
    }
}

/// The words the app gives the mail: the category in the person's
/// language for the subject, and the body, their text first.
package struct ReportMail: Equatable {
    package let category: String
    package let body: String

    package init(category: String, body: String) {
        self.category = category
        self.body = body
    }
}

/// One file written for a report, and its text for the preview.
package struct PreparedReport: Equatable {
    package let file: URL
    package let text: String

    package init(file: URL, text: String) {
        self.file = file
        self.text = text
    }
}

/// Where the report stands: nothing asked, the hosts being asked, the file
/// ready for the draft it was made from, or a file that could not be written.
package enum ReportPreparation: Equatable {
    case idle
    case preparing(ReportDraft)
    case ready(ReportDraft, PreparedReport)
    case failed(ReportDraft)
}

/// The report page's slice: the controllers it can concern, what the
/// summary under the person's words reads, and the preparation.
package struct ReportFacts: Equatable {
    package let controllers: [ControllerFact]
    package let localNetwork: LocalNetworkStatus
    package let controllerDb: ControllerDbFacts
    package let preparation: ReportPreparation

    package init(
        controllers: [ControllerFact],
        localNetwork: LocalNetworkStatus,
        controllerDb: ControllerDbFacts,
        preparation: ReportPreparation
    ) {
        self.controllers = controllers
        self.localNetwork = localNetwork
        self.controllerDb = controllerDb
        self.preparation = preparation
    }
}
