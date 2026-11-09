// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The pads iOS sees and what is kept for each: its switches, the global
/// switches above them, its "Emulate as" pick and its dead zones. One value,
/// so the composition root takes the controller side as one part.
@MainActor
package struct ControllerStack {
    package let source: any ControllerSource
    let switches: SlotPreferenceStore
    let features: FeatureSettings
    let types: ControllerTypeStore
    let deadzones: DeadzonePreferenceStore

    package init(
        source: any ControllerSource,
        switches: SlotPreferenceStore,
        features: FeatureSettings,
        types: ControllerTypeStore,
        deadzones: DeadzonePreferenceStore
    ) {
        self.source = source
        self.switches = switches
        self.features = features
        self.types = types
        self.deadzones = deadzones
    }

    /// Every store over the same defaults.
    package init(source: any ControllerSource, defaults: UserDefaults) {
        self.init(
            source: source,
            switches: SlotPreferenceStore(defaults: defaults),
            features: FeatureSettings(defaults: defaults),
            types: ControllerTypeStore(defaults: defaults),
            deadzones: DeadzonePreferenceStore(defaults: defaults)
        )
    }
}
