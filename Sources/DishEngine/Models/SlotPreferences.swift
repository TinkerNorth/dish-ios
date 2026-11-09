// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// The switches a controller carries on its own, beneath the global ones:
/// motion, rumble, the touchpad, and on iOS the light bar, the adaptive
/// triggers and the player LEDs, which the controller page lists beside
/// them. An unwritten switch is on. iOS gives apps no pad microphone or
/// speaker, so dish-mac's two audio switches have no field here.
package struct SlotPreferences: Hashable {
    package var motion = true
    package var rumble = true
    package var touchpad = true
    package var lightbar = true
    package var triggerEffects = true
    package var playerLeds = true

    package init(
        motion: Bool = true,
        rumble: Bool = true,
        touchpad: Bool = true,
        lightbar: Bool = true,
        triggerEffects: Bool = true,
        playerLeds: Bool = true
    ) {
        self.motion = motion
        self.rumble = rumble
        self.touchpad = touchpad
        self.lightbar = lightbar
        self.triggerEffects = triggerEffects
        self.playerLeds = playerLeds
    }

    package func isOn(_ toggle: SlotSwitch) -> Bool {
        switch toggle {
        case .motion: motion
        case .rumble: rumble
        case .touchpad: touchpad
        case .lightbar: lightbar
        case .triggerEffects: triggerEffects
        case .playerLeds: playerLeds
        }
    }

    package func with(_ toggle: SlotSwitch, _ enabled: Bool) -> SlotPreferences {
        var next = self
        switch toggle {
        case .motion: next.motion = enabled
        case .rumble: next.rumble = enabled
        case .touchpad: next.touchpad = enabled
        case .lightbar: next.lightbar = enabled
        case .triggerEffects: next.triggerEffects = enabled
        case .playerLeds: next.playerLeds = enabled
        }
        return next
    }
}

/// The switches a controller carries, in the order the controller page
/// lists them, for the intent that flips one.
package enum SlotSwitch: CaseIterable, Hashable {
    case motion
    case rumble
    case triggerEffects
    case lightbar
    case playerLeds
    case touchpad

    /// Whether the pad has the hardware the switch is for.
    package func isCarried(by capabilities: ControllerCapabilities) -> Bool {
        switch self {
        case .motion: capabilities.hasMotion
        case .rumble: capabilities.hasRumble
        case .triggerEffects: capabilities.hasTriggerEffects
        case .lightbar: capabilities.hasLightbar
        case .playerLeds: capabilities.hasPlayerLeds
        case .touchpad: capabilities.hasTouchpad
        }
    }
}

/// The switches that reach the wire, the hot path and the return paths for
/// one controller: the global switch and the controller's own, both on. The
/// trigger effects and the player LEDs have no global switch.
package func effectiveFlags(global: ForwardingFlags, slot: SlotPreferences) -> ForwardingFlags {
    ForwardingFlags(
        motion: global.motion && slot.motion,
        touchpad: global.touchpad && slot.touchpad,
        rumble: global.rumble && slot.rumble,
        lightbar: global.lightbar && slot.lightbar,
        triggerEffects: slot.triggerEffects,
        playerLeds: slot.playerLeds
    )
}

/// The per-controller switches, keyed by the slot's stable id, kept in
/// `UserDefaults` as the fleet keeps them: one JSON array per feature, each
/// row `{"slotId": …, "enabled": …}`, under dish-mac's `motion_preferences`,
/// `rumble_preferences` and `touchpad_preferences`, and under
/// `lightbar_preferences`, `trigger_effects_preferences` and
/// `player_leds_preferences` for the three iOS lists beside them. A garbled
/// blob reads as an empty list: losing the switches beats bricking startup.
@MainActor
package final class SlotPreferenceStore {
    static let motionKey = "motion_preferences"
    static let rumbleKey = "rumble_preferences"
    static let touchpadKey = "touchpad_preferences"
    static let lightbarKey = "lightbar_preferences"
    static let triggerEffectsKey = "trigger_effects_preferences"
    static let playerLedsKey = "player_leds_preferences"

    private static let keys: [(SlotSwitch, String)] = [
        (.motion, motionKey),
        (.rumble, rumbleKey),
        (.touchpad, touchpadKey),
        (.lightbar, lightbarKey),
        (.triggerEffects, triggerEffectsKey),
        (.playerLeds, playerLedsKey)
    ]

    private let defaults: UserDefaults
    private let source: StateSource<[String: SlotPreferences]>

    package var state: [String: SlotPreferences] {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        source = StateSource(initial: Self.read(defaults))
    }

    /// A controller never switched reads as all on.
    package func preferences(for slotId: String) -> SlotPreferences {
        state[slotId] ?? SlotPreferences()
    }

    /// Persists and republishes; the same switch twice is one change.
    package func set(_ toggle: SlotSwitch, _ enabled: Bool, for slotId: String) {
        let current = preferences(for: slotId)
        guard current.isOn(toggle) != enabled else { return }
        var all = state
        all[slotId] = current.with(toggle, enabled)
        source.setState(all)
        write(all)
    }

    private func write(_ all: [String: SlotPreferences]) {
        for (toggle, key) in Self.keys {
            defaults.set(Self.rows(all, toggle), forKey: key)
        }
    }

    /// One row per controller, in a stable order, as the fleet's JSON shape.
    private static func rows(_ all: [String: SlotPreferences], _ toggle: SlotSwitch) -> String {
        let rows = all.keys.sorted().map { slotId in
            ["slotId": slotId, "enabled": (all[slotId] ?? SlotPreferences()).isOn(toggle)] as [String: Any]
        }
        let data = try? JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private static func read(_ defaults: UserDefaults) -> [String: SlotPreferences] {
        var all: [String: SlotPreferences] = [:]
        for (toggle, key) in keys {
            for (slotId, enabled) in parse(defaults.string(forKey: key)) {
                all[slotId] = (all[slotId] ?? SlotPreferences()).with(toggle, enabled)
            }
        }
        return all
    }

    /// The rows of one feature's list; anything but a list of
    /// `{slotId, enabled}` rows reads as nothing written.
    static func parse(_ json: String?) -> [(String, Bool)] {
        guard let json, let rows = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]] else { return [] }
        return rows.compactMap(row)
    }

    private static func row(_ fields: [String: Any]) -> (String, Bool)? {
        guard let slotId = fields["slotId"] as? String, !slotId.isEmpty, let enabled = fields["enabled"] as? Bool else { return nil }
        return (slotId, enabled)
    }
}
