// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// Which battery a pad's host is sent, the fleet's rule (dish-android's
// BatteryRouting.kt, dish-linux's and dish-windows' BatteryRouting.h): two
// batteries compete, the pad's own and the device's Dish runs on, and the
// host is sent the lower, whatever the pad's link; the card keeps the pad's.

import Foundation

/// The charge state of a battery reading: a pad's own (`GCDeviceBattery`)
/// or the iPhone's or iPad's (`UIDevice`).
package enum BatteryChargeState: Hashable {
    case unknown, discharging, charging, full
}

/// A battery reading. `level` is 0...100, or nil when the battery reports a
/// state but not a percentage.
package struct BatteryReading: Hashable {
    package var level: Int?
    package var state: BatteryChargeState = .unknown

    package init(level: Int? = nil, state: BatteryChargeState = .unknown) {
        self.level = level
        self.state = state
    }
}

/// A battery's 0...1 level as a reading's percentage. GameController and
/// UIKit both report an unknown level as a negative one, which is none.
package func batteryPercent(_ level: Float) -> Int? {
    level < 0 ? nil : Int(min(level, 1) * 100.0 + 0.5)
}

/// Where a pad's battery goes: its own reading to its card, the routed one
/// to its host.
package struct RoutedBattery: Equatable {
    /// The pad's own reading; nil for a pad with no battery.
    package let display: BatteryReading?
    /// What the host is sent; nil when neither battery has a reading.
    package let wire: BatteryReading?
}

/// The card keeps the pad's own reading; the host is sent the lower of the
/// pad's and the device's. An unknown level sorts above every known one, a
/// tie goes to the pad, the charge state travels with the level that won,
/// and a pad with no battery sends the device's. The link takes no part: a
/// wired pad that reports its charge competes like any other.
package func routeBattery(pad: BatteryReading?, device: BatteryReading?) -> RoutedBattery {
    RoutedBattery(display: pad, wire: lowerBattery(pad, device))
}

/// The lower of the two readings, the pad's on a tie; either alone when the
/// other is missing.
private func lowerBattery(_ pad: BatteryReading?, _ device: BatteryReading?) -> BatteryReading? {
    guard let pad else { return device }
    guard let device else { return pad }
    return comparableLevel(device) < comparableLevel(pad) ? device : pad
}

/// An unknown level sorts as +infinity, so any known level is lower.
private func comparableLevel(_ reading: BatteryReading) -> Int {
    reading.level ?? Int.max
}
