// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The battery of the iPhone or iPad Dish runs on, as a seam: the scene
/// hands the model the device's own (`UIDevice`), since the engine imports
/// no UIKit, and a pad's host is sent the lower of it and the pad's.
@MainActor
package protocol DeviceBattery: AnyObject {
    /// The device's battery now; nil while the device reports none.
    var reading: BatteryReading? { get }
}

/// A device that reports no battery: a model built outside the scene, in a
/// test or a preview.
@MainActor
package final class InertDeviceBattery: DeviceBattery {
    package init() {}

    package var reading: BatteryReading? {
        nil
    }
}
