// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The ds4 > mouse > off ladder that turns the user's pick for a controller's
// touchpad into the `touchpadMode` its descriptor declares (a port of
// dish-linux TouchpadModeResolve.h). A pick the path cannot carry declares
// off rather than a request the satellite would dead-letter, and a blocked
// pick never falls back to the other routing: the pad render is a per-type
// concern, mouse control is host-injected.

import Foundation

public extension TouchpadPick {
    /// The stored and wire name, the satellite's own: `"off"`, `"ds4"`,
    /// `"mouse"`, plus the client-side `"stick"`, which declares `off` on the
    /// wire. An unknown name reads as off, the server's default too.
    init(wireName: String) {
        switch wireName {
        case "ds4": self = .pad
        case "mouse": self = .mouse
        case "stick": self = .stick
        default: self = .off
        }
    }

    var wireName: String {
        switch self {
        case .off: "off"
        case .pad: "ds4"
        case .mouse: "mouse"
        case .stick: "stick"
        }
    }

    /// The picker's order, pinned so the list is stable across builds.
    static let pickerOrder: [TouchpadPick] = [.off, .pad, .mouse]

    /// Whether the pick puts anything on the wire's touch surface.
    var carriesSurface: Bool {
        switch self {
        case .pad, .mouse: true
        case .off, .stick: false
        }
    }
}

/// The picks a Steam Controller's trackpads offer, in the picker's order:
/// the 2026 pad has a real right stick, so the stick is not one of its, and
/// iOS sends no pointer frame from a pad, so the mouse is no one's. A pad
/// without trackpads has no picker.
package func trackpadPickChoices(_ trackpads: SteamTrackpads) -> [TouchpadPick] {
    switch trackpads {
    case .none: []
    case .rightStickByDefault: [.stick, .pad, .off]
    case .twoPads: [.pad, .off]
    }
}

/// The pick a Steam Controller starts on: the 2015 pad's right trackpad is
/// its right stick, the 2026 pad's trackpads are a touchpad when the emulated
/// type has one and off otherwise.
package func defaultTrackpadPick(_ trackpads: SteamTrackpads, typeOffersDs4: Bool) -> TouchpadPick {
    switch trackpads {
    case .none: .off
    case .rightStickByDefault: .stick
    case .twoPads: typeOffersDs4 ? .pad : .off
    }
}

/// The pick in force: the stored one where the model offers it, else the
/// model's default, then held to what the path carries. A pad surface needs
/// the emulated type to have one; a mouse is never in force on iOS. One pick
/// covers both pads, so `pad` on the 2015 model gives up its right stick.
package func effectiveTrackpadPick(stored: TouchpadPick?, trackpads: SteamTrackpads, typeOffersDs4: Bool) -> TouchpadPick {
    let offered = stored.flatMap { trackpadPickChoices(trackpads).contains($0) ? $0 : nil }
    let wanted = offered ?? defaultTrackpadPick(trackpads, typeOffersDs4: typeOffersDs4)
    switch wanted {
    case .stick: return .stick
    case .pad: return typeOffersDs4 ? .pad : .off
    case .mouse, .off: return .off
    }
}

/// Only a genuine wire string survives the round trip unchanged.
public func isValidTouchpadPickName(_ name: String) -> Bool {
    TouchpadPick(wireName: name).wireName == name
}

/// A touchpad-bearing type with no `ds4` lineage gates the pad render off. A
/// pre-modes catalog omits `modes`; empty therefore means pad-capable.
public func typeOffersDs4Touchpad(supported: Bool, modes: [String]) -> Bool {
    supported && (modes.isEmpty || modes.contains(TouchpadPick.pad.wireName))
}

/// The mode a descriptor declares for the pick: the pad render needs a
/// touchpad and a type that offers it; the mouse needs a touchpad and a host
/// that advertises mouse control; off is off.
package func resolveTouchpadMode(pick: TouchpadPick, padHasTouchpad: Bool, typeOffersDs4: Bool, hostMouseControl: Bool) -> TouchpadMode {
    switch pick {
    case .pad: padHasTouchpad && typeOffersDs4 ? .ds4 : .off
    case .mouse: padHasTouchpad && hostMouseControl ? .mouse : .off
    case .off, .stick: .off
    }
}
