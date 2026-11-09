// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation

/// Each pad's dead zones under the desktops' keys: one `deadzone:<slotId>`
/// entry per pad tuned, in their `{"s":…,"t":…}` shape. A pad never tuned
/// reads the defaults, and a value that does not read is nothing stored.
@MainActor
package final class DeadzonePreferenceStore {
    static let keyPrefix = "deadzone:"

    private let defaults: UserDefaults
    private let source: StateSource<[String: DeadzoneSetting]>

    package var state: [String: DeadzoneSetting] {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        source = StateSource(initial: Self.read(defaults))
    }

    package func zones(for slotId: String) -> DeadzoneSetting {
        state[slotId] ?? .defaults
    }

    package func setZones(_ zones: DeadzoneSetting, for slotId: String) {
        guard state[slotId] != zones else { return }
        defaults.set(zones.storedJson, forKey: Self.keyPrefix + slotId)
        var next = state
        next[slotId] = zones
        source.setState(next)
    }

    package func reset(_ slotId: String) {
        defaults.removeObject(forKey: Self.keyPrefix + slotId)
        var next = state
        next.removeValue(forKey: slotId)
        source.setState(next)
    }

    private static func read(_ defaults: UserDefaults) -> [String: DeadzoneSetting] {
        let stored = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix(keyPrefix) }
        var all: [String: DeadzoneSetting] = [:]
        for (key, value) in stored {
            let slotId = String(key.dropFirst(keyPrefix.count))
            all[slotId] = DeadzoneSetting(storedJson: value as? String)
        }
        return all
    }
}
