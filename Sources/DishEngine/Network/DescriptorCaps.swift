// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The caps word a descriptor advertises. A cap is a promise that the
/// matching stream or return path lands, so it needs both the hardware and
/// the user's switch: a feature turned off is not advertised. Analog
/// triggers ride every extended gamepad. iOS gives apps no pad microphone or
/// speaker, so the audio caps are never claimed.
func descriptorCaps(_ capabilities: ControllerCapabilities, _ flags: ForwardingFlags) -> UInt16 {
    let claims: [(claimed: Bool, bit: UInt16)] = [
        (true, ProtocolConstants.capAnalogTriggers),
        (capabilities.hasRumble && flags.rumble, ProtocolConstants.capRumble),
        (capabilities.hasMotion && flags.motion, ProtocolConstants.capMotion),
        (capabilities.hasLightbar && flags.lightbar, ProtocolConstants.capLightbar),
        (capabilities.hasTriggerEffects && flags.triggerEffects, ProtocolConstants.capTriggerEffects),
        (capabilities.hasPlayerLeds && flags.playerLeds, ProtocolConstants.capPlayerLeds)
    ]
    return claims.filter(\.claimed).reduce(UInt16(0)) { $0 | $1.bit }
}

/// The touchpad mode a descriptor asks for: the screen the phone lends the
/// slot, else the pad's own touchpad as the pad render, else off.
func descriptorTouchpadMode(
    _ capabilities: ControllerCapabilities,
    _ flags: ForwardingFlags,
    typeOffersDs4: Bool = true,
    hostMouseControl: Bool = false
) -> TouchpadMode {
    switch flags.phoneSurface {
    case .mouse: return hostMouseControl ? .mouse : .off
    case .touchpad: return typeOffersDs4 ? .ds4 : .off
    case nil: break
    }
    return resolveTouchpadMode(
        pick: flags.touchpad ? .pad : .off,
        padHasTouchpad: capabilities.hasTouchpad,
        typeOffersDs4: typeOffersDs4,
        hostMouseControl: hostMouseControl
    )
}

/// Whether the catalog type a pad is emulated as renders a touchpad; a
/// catalog not read, or a type it does not name, refuses nothing.
func typeOffersDs4Touchpad(in catalog: CatalogDTO?, type: Int) -> Bool {
    guard let row = catalog?.controllerTypes.first(where: { $0.id == type }) else { return true }
    return typeOffersDs4Touchpad(supported: row.features.touchpad.supported, modes: row.features.touchpad.modes)
}

/// The `sdlType` values a pick is emulated as, best first.
func emulationCandidates(for pad: EmulatedPad) -> [String] {
    switch pad {
    case .dualSense: ["ps5", "ps4"]
    case .dualShock4: ["ps4", "ps5"]
    case .xboxWireless: ["xbox360", "xboxone"]
    case .switchPro: ["switchpro"]
    }
}

/// The catalog type a pad is emulated as: the first candidate the catalog
/// offers under `emulates.sdlType`, else the first type offered, else the
/// legacy Xbox target when there is no catalog at all.
func preferredControllerType(in catalog: CatalogDTO?, for pad: EmulatedPad) -> Int {
    guard let types = catalog?.controllerTypes, let first = types.first else {
        return Int(ProtocolConstants.controllerTypeXbox)
    }
    for candidate in emulationCandidates(for: pad) {
        if let match = types.first(where: { $0.emulates?.sdlType == candidate }) {
            return match.id
        }
    }
    return first.id
}
