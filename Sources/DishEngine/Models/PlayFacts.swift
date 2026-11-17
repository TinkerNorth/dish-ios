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

/// The slot the phone's touches serve: the on-screen controller, or a pad
/// the phone lends its touchpad or mouse to.
package enum PlayTarget: Equatable {
    case onScreen
    case pad(id: String, name: String)
}

/// The screens the phone can lend a pad: none for a pad with a touchpad of
/// its own or a session that is down; the touchpad when the type renders
/// one; the mouse when the host grants it.
package func lentScreens(padHasTouchpad: Bool, sessionUp: Bool, typeOffersDs4: Bool, hostMouseControl: Bool) -> [PlayScreen] {
    let phoneSourced = !padHasTouchpad && sessionUp
    let offered: [(screen: PlayScreen, open: Bool)] = [(.touchpad, typeOffersDs4), (.mouse, hostMouseControl)]
    return phoneSourced ? offered.filter(\.open).map(\.screen) : []
}

/// The play screen on display, the slot it serves, its PC, and the
/// on-screen controller's switches.
package struct PlayFacts: Equatable {
    package let screen: PlayScreen
    package let target: PlayTarget
    /// The PC the served slot is bound to; nil while it is unbound.
    package let destination: DestinationFact?
    package let emulateAs: EmulatedPad
    package let rumble: Bool
    package let motion: Bool
    package let motionAvailability: PlayMotion

    package init(
        screen: PlayScreen,
        target: PlayTarget = .onScreen,
        destination: DestinationFact? = nil,
        emulateAs: EmulatedPad,
        rumble: Bool,
        motion: Bool,
        motionAvailability: PlayMotion
    ) {
        self.screen = screen
        self.target = target
        self.destination = destination
        self.emulateAs = emulateAs
        self.rumble = rumble
        self.motion = motion
        self.motionAvailability = motionAvailability
    }
}
