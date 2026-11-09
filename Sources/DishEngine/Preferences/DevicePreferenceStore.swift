// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// The name this iPhone gives Satellite. iOS tells apps only "iPhone", so the
/// person names it; empty means they have not. Stored trimmed, and the setter
/// is idempotent.
@MainActor
package final class DevicePreferenceStore {
    static let nameKey = "device_name"

    private let defaults: UserDefaults
    private let source: StateSource<String>

    package var state: String {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        source = StateSource(initial: defaults.string(forKey: Self.nameKey) ?? "")
    }

    package func setDeviceName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != state else { return }
        defaults.set(trimmed, forKey: Self.nameKey)
        source.setState(trimmed)
    }
}
