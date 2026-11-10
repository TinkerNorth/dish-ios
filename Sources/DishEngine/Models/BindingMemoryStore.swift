// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// A pad's standing binding to a satellite, as kept across restarts: the
/// satellite's remembered id (its machine id). dish-mac also keeps the pick
/// in the record; here the pick is the pad's own, under
/// `emulated_type_preferences`, so a record has one truth to read.
struct RememberedSatelliteBinding: Equatable, Codable {
    var slotId: String
    var satelliteId: String
}

/// The satellite bindings under `wifi_binding_list`, one record per pad.
/// Plain reads over the defaults, so every reader sees one truth; a value
/// that does not read is nothing stored. On the main actor, where every
/// reader of `UserDefaults` in this engine is.
@MainActor
struct BindingMemoryStore {
    static let bindingsKey = "wifi_binding_list"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func bindings() -> [RememberedSatelliteBinding] {
        guard let raw = defaults.data(forKey: Self.bindingsKey) else { return [] }
        return (try? JSONDecoder().decode([RememberedSatelliteBinding].self, from: raw)) ?? []
    }

    /// The pad's record, replacing whatever it had.
    func remember(_ binding: RememberedSatelliteBinding) {
        write(bindings().filter { $0.slotId != binding.slotId } + [binding])
    }

    func forget(slotId: String) {
        write(bindings().filter { $0.slotId != slotId })
    }

    func forgetSatellite(_ satelliteId: String) {
        write(bindings().filter { $0.satelliteId != satelliteId })
    }

    private func write(_ bindings: [RememberedSatelliteBinding]) {
        defaults.set(try? JSONEncoder().encode(bindings), forKey: Self.bindingsKey)
    }
}
