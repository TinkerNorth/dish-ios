// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// How the controller light bar behaves while a pad is bound: the colour the
/// game writes, or left alone.
package enum LightbarMode: String, CaseIterable {
    case followGame
    case off
}

/// The switches that reach the hot path and the return paths, as one value
/// the main actor hands across. `touchpad` and `motion` gate what is sent,
/// the others what the pad acts on.
package struct ForwardingFlags: Hashable {
    package var motion = true
    package var touchpad = true
    package var rumble = true
    package var lightbar = true
    package var triggerEffects = true
    package var playerLeds = true

    package init(
        motion: Bool = true,
        touchpad: Bool = true,
        rumble: Bool = true,
        lightbar: Bool = true,
        triggerEffects: Bool = true,
        playerLeds: Bool = true
    ) {
        self.motion = motion
        self.touchpad = touchpad
        self.rumble = rumble
        self.lightbar = lightbar
        self.triggerEffects = triggerEffects
        self.playerLeds = playerLeds
    }
}

/// The global switches, above every controller's own, under dish-mac's
/// keys: `feature_motion_enabled`, `feature_rumble_enabled`,
/// `feature_touchpad_enabled` and `feature_lightbar_mode`. A fresh install
/// has everything on and the light bar following the game. They gate whether
/// Dish sends or acts on a feature, never what the hardware reports.
@MainActor
package final class FeatureSettings {
    static let motionKey = "feature_motion_enabled"
    static let rumbleKey = "feature_rumble_enabled"
    static let touchpadKey = "feature_touchpad_enabled"
    static let lightbarKey = "feature_lightbar_mode"

    private let defaults: UserDefaults
    private let source: StateSource<ForwardingFlags>

    /// The global switches as flags; the light bar is on while it follows the game.
    package var flags: ForwardingFlags {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        let lightbar = defaults.string(forKey: Self.lightbarKey).flatMap(LightbarMode.init(rawValue:)) ?? .followGame
        source = StateSource(initial: ForwardingFlags(
            motion: defaults.object(forKey: Self.motionKey) as? Bool ?? true,
            touchpad: defaults.object(forKey: Self.touchpadKey) as? Bool ?? true,
            rumble: defaults.object(forKey: Self.rumbleKey) as? Bool ?? true,
            lightbar: lightbar == .followGame
        ))
    }

    package var lightbarMode: LightbarMode {
        flags.lightbar ? .followGame : .off
    }

    package func setMotion(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.motionKey)
        source.updateState { $0.with(\.motion, enabled) }
    }

    package func setRumble(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.rumbleKey)
        source.updateState { $0.with(\.rumble, enabled) }
    }

    package func setTouchpad(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.touchpadKey)
        source.updateState { $0.with(\.touchpad, enabled) }
    }

    package func setLightbarMode(_ mode: LightbarMode) {
        defaults.set(mode.rawValue, forKey: Self.lightbarKey)
        source.updateState { $0.with(\.lightbar, mode == .followGame) }
    }
}

extension ForwardingFlags {
    func with(_ field: WritableKeyPath<ForwardingFlags, Bool>, _ value: Bool) -> ForwardingFlags {
        var next = self
        next[keyPath: field] = value
        return next
    }
}
