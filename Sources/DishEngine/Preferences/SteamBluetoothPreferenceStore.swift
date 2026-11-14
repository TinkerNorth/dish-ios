// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// Whether Dish reads Steam Controllers over Bluetooth, under
/// `steam_bluetooth_enabled`: off on a fresh install, so nobody without one
/// is asked for Bluetooth, as the Mac's Direct pads wait to be picked.
@MainActor
package final class SteamBluetoothPreferenceStore {
    static let enabledKey = "steam_bluetooth_enabled"

    private let defaults: UserDefaults
    private let source: StateSource<Bool>

    package var enabled: Bool {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        source = StateSource(initial: defaults.object(forKey: Self.enabledKey) as? Bool ?? false)
    }

    package func setEnabled(_ enabled: Bool) {
        guard enabled != self.enabled else { return }
        defaults.set(enabled, forKey: Self.enabledKey)
        source.setState(enabled)
    }
}
