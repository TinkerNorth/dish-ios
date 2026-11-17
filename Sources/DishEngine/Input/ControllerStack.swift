// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The pads Dish reads and what is kept for each: GameController's pads,
/// the Steam Controllers over Bluetooth and whether the person reads them,
/// each pad's switches, the global switches above them, its "Emulate as"
/// pick, a Steam Controller's trackpad pick and its dead zones. One value,
/// so the composition root takes the controller side as one part.
@MainActor
package struct ControllerStack {
    package let source: any ControllerSource
    package let steam: SteamBluetoothPads
    let steamSetting: SteamBluetoothPreferenceStore
    let switches: SlotPreferenceStore
    let features: FeatureSettings
    let types: ControllerTypeStore
    let trackpads: TrackpadPickStore
    let deadzones: DeadzonePreferenceStore

    package init(
        source: any ControllerSource,
        steam: SteamBluetoothPads,
        steamSetting: SteamBluetoothPreferenceStore,
        switches: SlotPreferenceStore,
        features: FeatureSettings,
        types: ControllerTypeStore,
        trackpads: TrackpadPickStore,
        deadzones: DeadzonePreferenceStore
    ) {
        self.source = source
        self.steam = steam
        self.steamSetting = steamSetting
        self.switches = switches
        self.features = features
        self.types = types
        self.trackpads = trackpads
        self.deadzones = deadzones
    }

    /// Every store over the same defaults; the Steam Controllers share the
    /// source's processor and feedback unless a test hands in its own.
    package init(source: any ControllerSource, defaults: UserDefaults, steam: SteamBluetoothPads? = nil) {
        self.init(
            source: source,
            steam: steam ?? SteamBluetoothPads(processor: source.processor, feedback: source.feedback),
            steamSetting: SteamBluetoothPreferenceStore(defaults: defaults),
            switches: SlotPreferenceStore(defaults: defaults),
            features: FeatureSettings(defaults: defaults),
            types: ControllerTypeStore(defaults: defaults),
            trackpads: TrackpadPickStore(defaults: defaults),
            deadzones: DeadzonePreferenceStore(defaults: defaults)
        )
    }

    /// Every pad Dish lists: GameController's, then the Steam Controllers.
    package var slots: [ControllerSlot] {
        source.slots + steam.slots
    }
}
