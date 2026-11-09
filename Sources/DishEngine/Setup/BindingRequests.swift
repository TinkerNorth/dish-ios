// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The bindings setup asked for, kept in order until the binding wave sends
/// them to the PC.
@MainActor
package final class BindingRequests {
    package private(set) var requests: [SetupDraft] = []

    package init() {}

    package func record(_ draft: SetupDraft) {
        requests.append(draft)
    }
}
