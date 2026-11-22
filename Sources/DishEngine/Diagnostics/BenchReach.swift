// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What a listed pad's path carries to the bench, as its capabilities say:
/// the motors Dish can drive, its light bar, player LEDs and adaptive
/// triggers, the surfaces the game's own writes reach, and its sticks once
/// Dish reads it. A pad Dish cannot read carries nothing.
func benchReach(_ slot: ControllerSlot) -> BenchReach {
    guard slot.readable else { return [] }
    let capabilities = slot.capabilities
    let surfaces: [(carried: Bool, reach: BenchReach)] = [
        (capabilities.hasLightbar, .lightbar),
        (capabilities.hasPlayerLeds, .playerLeds),
        (capabilities.hasTriggerEffects, .adaptiveTriggers),
        (true, .sticks)
    ]
    return surfaces.filter(\.carried).reduce(capabilities.motors) { $0.union($1.reach) }
}

/// The on-screen controller's: the phone's one actuator, where it has one.
/// Its sticks are the gamepad screen's, a cover that hides the bench while
/// it is up, so no stick test could reach them.
func onScreenBenchReach(phoneHaptics: Bool) -> BenchReach {
    phoneHaptics ? [.oneActuator] : []
}
