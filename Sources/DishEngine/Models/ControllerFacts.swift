// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

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

/// A controller Dish knows: a pad on a link, or the on-screen gamepad.
package struct ControllerFact: Equatable, Identifiable {
    package let id: String
    package let name: String
    package let link: ControllerLink
    /// Nil when the pad does not report a level (the on-screen gamepad).
    package let batteryPercent: Int?
    /// Nil while the controller is bound to no PC.
    package let destination: DestinationFact?

    package init(id: String, name: String, link: ControllerLink, batteryPercent: Int?, destination: DestinationFact?) {
        self.id = id
        self.name = name
        self.link = link
        self.batteryPercent = batteryPercent
        self.destination = destination
    }
}
