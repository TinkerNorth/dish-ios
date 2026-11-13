// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation

/// The user's "Emulate as" pick per pad: slot id to the pad it is emulated
/// as. No pick means the pad's family picks. dish-mac keeps its pick in
/// memory per (satellite, pad) and remembers it with the binding in
/// `wifi_binding_list`; the iOS controller page offers the pick before any
/// binding exists, so it is kept per pad under `emulated_type_preferences`,
/// one JSON object of slot id to the type's stored word.
@MainActor
package final class ControllerTypeStore {
    static let typesKey = "emulated_type_preferences"

    private let defaults: UserDefaults
    private let source: StateSource<[String: EmulatedPad]>

    package var state: [String: EmulatedPad] {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: Self.typesKey) ?? [:]
        source = StateSource(initial: stored.compactMapValues { ($0 as? String).flatMap(emulatedPad(storedWord:)) })
    }

    package func typeFor(_ slotId: String) -> EmulatedPad? {
        state[slotId]
    }

    package func setType(_ type: EmulatedPad, for slotId: String) {
        guard state[slotId] != type else { return }
        var next = state
        next[slotId] = type
        write(next)
    }

    /// Back to the family's own type. A no-op for a pad with no pick.
    package func clear(_ slotId: String) {
        guard state[slotId] != nil else { return }
        var next = state
        next.removeValue(forKey: slotId)
        write(next)
    }

    private func write(_ types: [String: EmulatedPad]) {
        defaults.set(types.mapValues(storedWord), forKey: Self.typesKey)
        source.setState(types)
    }
}

/// The word a type is stored under, stable across releases.
func storedWord(_ pad: EmulatedPad) -> String {
    switch pad {
    case .dualSense: "dualsense"
    case .dualShock4: "dualshock4"
    case .xboxWireless: "xbox"
    case .switchPro: "switchpro"
    case .dualSenseEdge: "dualsenseedge"
    }
}

/// The type a stored word names; nil for a word this build does not know.
func emulatedPad(storedWord word: String) -> EmulatedPad? {
    EmulatedPad.allCases.first { storedWord($0) == word }
}
