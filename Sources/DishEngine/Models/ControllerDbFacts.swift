// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The controller data as Settings and Diagnostics show it: where the set
/// in force came from and how the last check ended, and the database's
/// words, which the app reads in the person's language.
package struct ControllerDbFacts: Equatable {
    package let status: ControllerDbStatus
    package let strings: ControllerStrings

    package init(status: ControllerDbStatus, strings: ControllerStrings) {
        self.status = status
        self.strings = strings
    }

    /// No copy read: a preview's, or a test's that names none.
    package static let none = ControllerDbFacts(
        status: ControllerDbStatus(bundledVersion: 0, activeVersion: 0, source: .bundled, checksEnabled: true),
        strings: ControllerStrings(tables: [:])
    )
}
