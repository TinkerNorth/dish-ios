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

/// What the Motion row needs of the PC: whether the pad's PC carries motion
/// now (its session is up), and the satellite's word from the last apply,
/// nil until it has given one.
package struct MotionFact: Equatable {
    package let carries: Bool
    package let status: MotionBackendStatus?

    package init(carries: Bool, status: MotionBackendStatus?) {
        self.carries = carries
        self.status = status
    }
}

/// What a pad on a Moonlight host is emulated as, in the protocol's own
/// numbering (0 Auto, 1 Xbox, 2 PlayStation, 3 Nintendo): the type its
/// binding holds, and whether the person picked it over the host's own.
package struct HostEmulationFact: Equatable {
    package let type: Int
    package let isOverride: Bool

    package init(type: Int, isOverride: Bool) {
        self.type = type
        self.isOverride = isOverride
    }
}

/// A Steam Controller's trackpad pick: the picks its model offers, in the
/// picker's order, and the one in force.
package struct TrackpadsFact: Equatable {
    package let choices: [TouchpadPick]
    package let pick: TouchpadPick

    package init(choices: [TouchpadPick], pick: TouchpadPick) {
        self.choices = choices
        self.pick = pick
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
    /// The PC's side of the Motion row.
    package let motion: MotionFact
    /// Nil unless the controller is bound to a Moonlight host.
    package let hostEmulation: HostEmulationFact?
    /// A Steam Controller's trackpads, in place of the Touchpad switch; nil
    /// for every other controller.
    package let trackpads: TrackpadsFact?

    package init(
        id: String,
        name: String,
        link: ControllerLink,
        batteryPercent: Int?,
        destination: DestinationFact?,
        family: PadFamily = .other,
        emulateAs: EmulatedPad = .xboxWireless,
        features: [ControllerFeatureFact] = [],
        supported: Bool = true,
        motion: MotionFact = MotionFact(carries: false, status: nil),
        hostEmulation: HostEmulationFact? = nil,
        trackpads: TrackpadsFact? = nil
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
        self.motion = motion
        self.hostEmulation = hostEmulation
        self.trackpads = trackpads
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
