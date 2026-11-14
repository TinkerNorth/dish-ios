// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation

/// Each Steam Controller's chosen trackpad pick, keyed by its slot id, under
/// dish-mac's `touchpad_mode_preferences`: one JSON array, each row
/// `{"slotId": …, "mode": …}` in the wire's words. Only a chosen pick is
/// written, so an unchosen pad follows its model's default. A garbled blob
/// or a mode that is no wire word reads as nothing chosen.
@MainActor
package final class TrackpadPickStore {
    static let picksKey = "touchpad_mode_preferences"

    private let defaults: UserDefaults
    private let source: StateSource<[String: TouchpadPick]>

    package var state: [String: TouchpadPick] {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        source = StateSource(initial: Self.parse(defaults.string(forKey: Self.picksKey)))
    }

    package func pick(for slotId: String) -> TouchpadPick? {
        state[slotId]
    }

    package func setPick(_ pick: TouchpadPick, for slotId: String) {
        guard state[slotId] != pick else { return }
        var next = state
        next[slotId] = pick
        defaults.set(Self.rows(next), forKey: Self.picksKey)
        source.setState(next)
    }

    private static func rows(_ picks: [String: TouchpadPick]) -> String {
        let rows = picks.keys.sorted().map { ["slotId": $0, "mode": (picks[$0] ?? .off).wireName] }
        let data = try? JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    static func parse(_ json: String?) -> [String: TouchpadPick] {
        guard let json, let rows = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]] else { return [:] }
        return Dictionary(rows.compactMap(row)) { _, last in last }
    }

    private static func row(_ fields: [String: Any]) -> (String, TouchpadPick)? {
        guard let slotId = fields["slotId"] as? String, !slotId.isEmpty, let mode = fields["mode"] as? String else { return nil }
        guard isValidTouchpadPickName(mode) else { return nil }
        return (slotId, TouchpadPick(wireName: mode))
    }
}
