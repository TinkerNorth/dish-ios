// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// Light, dark or the system's, under the fleet's key and dish-mac's raw
/// values. An unknown stored value reads as the system's, so a newer
/// client's mode never breaks an older one. The setter is idempotent.
@MainActor
package final class AppearancePreferenceStore {
    static let modeKey = "theme_mode"

    private let defaults: UserDefaults
    private let source: StateSource<Appearance>

    package var state: Appearance {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.modeKey).flatMap(Appearance.init(rawValue:))
        source = StateSource(initial: stored ?? .system)
    }

    package func setAppearance(_ appearance: Appearance) {
        guard appearance != state else { return }
        defaults.set(appearance.rawValue, forKey: Self.modeKey)
        source.setState(appearance)
    }
}
