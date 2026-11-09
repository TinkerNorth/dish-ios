// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The page the model's walk opens on for a navigation entry: the first run
/// and the guide meet the welcome, "Add a controller" goes straight to Input.
/// The scene hands `NavigationStore` `{ model.startSetup(setupStart($0)) }`.
func setupStart(_ entry: SetupEntry) -> SetupStart {
    switch entry {
    case .firstRun, .guide: .welcome
    case .addController: .input
    }
}
