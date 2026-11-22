// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The bench's facts: the controllers, what each one's path reaches by its
/// slot id, and where the bench stands.
package struct BenchFacts: Equatable {
    package let controllers: [ControllerFact]
    package let reach: [String: BenchReach]
    package let bench: BenchState

    package init(controllers: [ControllerFact], reach: [String: BenchReach], bench: BenchState = BenchState()) {
        self.controllers = controllers
        self.reach = reach
        self.bench = bench
    }
}
