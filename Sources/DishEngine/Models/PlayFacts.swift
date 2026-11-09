// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The three play screens, each a surface of the on-screen controller.
package enum PlayScreen: CaseIterable, Hashable {
    case gamepad
    case touchpad
    case mouse
}

/// Whether the pause menu's Motion can be on, and why not.
package enum PlayMotion: Equatable {
    case available
    /// The emulated pad carries no motion (an Xbox pad).
    case padHasNone
    /// This iPhone has no motion sensors.
    case phoneHasNone
}

/// The play screen on display and the on-screen controller's switches.
package struct PlayFacts: Equatable {
    package let screen: PlayScreen
    package let emulateAs: EmulatedPad
    package let rumble: Bool
    package let motion: Bool
    package let motionAvailability: PlayMotion

    package init(screen: PlayScreen, emulateAs: EmulatedPad, rumble: Bool, motion: Bool, motionAvailability: PlayMotion) {
        self.screen = screen
        self.emulateAs = emulateAs
        self.rumble = rumble
        self.motion = motion
        self.motionAvailability = motionAvailability
    }
}
