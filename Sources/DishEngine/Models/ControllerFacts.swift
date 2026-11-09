// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// How a controller reaches this iPhone.
package enum ControllerLink: Equatable {
    case usbC
    case bluetooth
    case onScreen
}

/// How well the PC a controller is bound to is answering.
package enum LinkHealth: Equatable {
    case online
    case unsteady
    case lost
}

/// The PC a controller sends to, and how it is answering.
package struct DestinationFact: Equatable {
    package let name: String
    package let health: LinkHealth

    package init(name: String, health: LinkHealth) {
        self.name = name
        self.health = health
    }
}

/// One switch a controller carries, and whether it is on.
package struct ControllerFeatureFact: Equatable {
    package let feature: SlotSwitch
    package let enabled: Bool

    package init(feature: SlotSwitch, enabled: Bool) {
        self.feature = feature
        self.enabled = enabled
    }
}

/// A controller Dish knows: a pad on a link, or the on-screen gamepad.
package struct ControllerFact: Equatable, Identifiable {
    package let id: String
    package let name: String
    package let link: ControllerLink
    /// Nil when the pad does not report a level (the on-screen gamepad).
    package let batteryPercent: Int?
    /// Nil while the controller is bound to no PC.
    package let destination: DestinationFact?
    package let family: PadFamily
    /// The pad the PC is to see: the user's pick, else the family's own.
    package let emulateAs: EmulatedPad
    /// The switches the pad has the hardware for, in the page's order.
    package let features: [ControllerFeatureFact]
    /// False for a pad iOS lists without the extended profile, which Dish
    /// cannot read.
    package let supported: Bool

    package init(
        id: String,
        name: String,
        link: ControllerLink,
        batteryPercent: Int?,
        destination: DestinationFact?,
        family: PadFamily = .other,
        emulateAs: EmulatedPad = .xboxWireless,
        features: [ControllerFeatureFact] = [],
        supported: Bool = true
    ) {
        self.id = id
        self.name = name
        self.link = link
        self.batteryPercent = batteryPercent
        self.destination = destination
        self.family = family
        self.emulateAs = emulateAs
        self.features = features
        self.supported = supported
    }
}

/// How an attached pad reaches the iPhone.
package enum PadLink: Hashable {
    case usbC
    case bluetooth
}

/// A pad attached to this iPhone, as setup offers it: its family picks the
/// default emulation, and its link and battery word its row.
package struct AttachedPadFact: Equatable, Identifiable {
    package let id: String
    package let name: String
    package let family: EmulatedPad
    package let link: PadLink
    package let batteryPercent: Int?

    package init(id: String, name: String, family: EmulatedPad, link: PadLink, batteryPercent: Int?) {
        self.id = id
        self.name = name
        self.family = family
        self.link = link
        self.batteryPercent = batteryPercent
    }
}
