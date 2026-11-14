// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What a physical controller's hardware exposes, detected once at attach.
/// Distinct from the switches, which say whether the user wants each
/// feature forwarded. iOS gives apps no pad microphone or speaker, so
/// dish-mac's audio capabilities have no field here.
package struct ControllerCapabilities: Hashable {
    package var hasMotion = false
    package var hasTouchpad = false
    package var hasRumble = false
    /// The controller has an addressable RGB light bar (`GCController.light`).
    package var hasLightbar = false
    package var hasBattery = false
    /// The pad takes the DualSense adaptive-trigger effects.
    package var hasTriggerEffects = false
    /// The pad has player-indicator LEDs the framework drives by player index.
    package var hasPlayerLeds = false
    /// The pad sources the protocol 4 extended buttons
    /// (`ProtocolConstants.extButton*`): the `extendedButtons` claim.
    package var hasExtendedButtons = false

    package init(
        hasMotion: Bool = false,
        hasTouchpad: Bool = false,
        hasRumble: Bool = false,
        hasLightbar: Bool = false,
        hasBattery: Bool = false,
        hasTriggerEffects: Bool = false,
        hasPlayerLeds: Bool = false,
        hasExtendedButtons: Bool = false
    ) {
        self.hasMotion = hasMotion
        self.hasTouchpad = hasTouchpad
        self.hasRumble = hasRumble
        self.hasLightbar = hasLightbar
        self.hasBattery = hasBattery
        self.hasTriggerEffects = hasTriggerEffects
        self.hasPlayerLeds = hasPlayerLeds
        self.hasExtendedButtons = hasExtendedButtons
    }

    package static let none = ControllerCapabilities()
}

/// The physical pad's family, decided once at attach from the framework's
/// product category. It picks the type the pad is emulated as. The
/// framework exports constants for the first three; Nintendo's pads are
/// known by the words the framework uses for them; everything else is a
/// generic pad.
package enum PadFamily: Hashable {
    case dualSense
    case dualShock4
    case xbox
    case nintendo
    case other

    /// The pad a fresh binding emulates: the family's own, and an Xbox
    /// Wireless pad for a family no catalog type names.
    package var emulatedPad: EmulatedPad {
        switch self {
        case .dualSense: .dualSense
        case .dualShock4: .dualShock4
        case .xbox, .other: .xboxWireless
        case .nintendo: .switchPro
        }
    }
}

/// The framework's words for Nintendo's pads, which the SDK exports no
/// constant for: "Switch Pro Controller", "Nintendo Switch Joy-Con (L/R)",
/// and the Switch Online N64, SNES and NES pads.
private let nintendoMarkers = ["switch pro", "joy-con", "n64", "snes", "nes controller", "nintendo"]

/// The family a pad's category or vendor name names, for a category the
/// framework has no constant for.
func namedPadFamily(productCategory: String, vendorName: String?) -> PadFamily {
    let words = [productCategory, vendorName ?? ""].map { $0.lowercased() }
    let namesNintendo = words.contains { word in nintendoMarkers.contains { word.contains($0) } }
    return namesNintendo ? .nintendo : .other
}

/// One controller Dish lists: a pad GameController vends, as the bridge
/// publishes it, or a Steam Controller read over Bluetooth. A pad without
/// the extended profile is listed but not read: iOS has no HID access, so
/// dish-mac's profile and USB Direct paths have no counterpart.
package struct ControllerSlot: Identifiable, Hashable {
    package let id: String
    package let name: String
    package var link: PadLink
    package var capabilities: ControllerCapabilities
    /// Nil until the first sample arrives, and for a pad without a battery.
    package var battery: BatteryReading?
    package var family: PadFamily
    /// The pad has the extended profile, so Dish reads it.
    package var readable: Bool
    /// A Steam Controller's trackpads, which its pick lands; none for every
    /// other pad.
    package var trackpads: SteamTrackpads

    package init(
        id: String,
        name: String,
        link: PadLink = .bluetooth,
        capabilities: ControllerCapabilities = .none,
        battery: BatteryReading? = nil,
        family: PadFamily = .other,
        readable: Bool = true,
        trackpads: SteamTrackpads = .none
    ) {
        self.id = id
        self.name = name
        self.link = link
        self.capabilities = capabilities
        self.battery = battery
        self.family = family
        self.readable = readable
        self.trackpads = trackpads
    }
}
