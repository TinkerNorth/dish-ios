// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The port an iPhone or iPad hosts a wired pad through, from the hardware's
/// model identifier: iOS names no port to an app.
package enum DevicePort: Equatable {
    case lightning
    case usbC
}

/// The port of the hardware a model identifier names, "iPhone15,4";
/// anything the table does not know reads as USB-C.
package func devicePort(modelIdentifier: String) -> DevicePort {
    guard let model = HardwareModel(modelIdentifier) else { return .usbC }
    switch model.family {
    case "iPhone": return model.generation > 15 || (model.generation == 15 && model.variant >= 4) ? .usbC : .lightning
    case "iPad": return model.generation == 8 || model.generation >= 13 ? .usbC : .lightning
    case "iPod": return .lightning
    default: return .usbC
    }
}

/// "iPhone15,4" taken apart: the family word, then its two numbers.
struct HardwareModel: Equatable {
    let family: String
    let generation: Int
    let variant: Int

    init?(_ identifier: String) {
        let family = identifier.prefix { $0.isLetter }
        let numbers = identifier.dropFirst(family.count).split(separator: ",", omittingEmptySubsequences: false)
        guard !family.isEmpty, numbers.count == 2, let generation = Int(numbers[0]), let variant = Int(numbers[1]) else { return nil }
        self.family = String(family)
        self.generation = generation
        self.variant = variant
    }
}
