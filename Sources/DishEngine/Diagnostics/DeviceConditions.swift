// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What the device says of its temperature and its power saving, as a
/// seam: the scene hands the model the process's own, and a test its
/// choice. The battery is `DeviceBattery`'s.
@MainActor
package protocol DeviceConditions: AnyObject {
    /// Nil where the device says nothing a reader can use.
    var thermal: BundleThermal? { get }
    var lowPowerMode: Bool? { get }
}

/// A device that says nothing: a model built outside the scene.
@MainActor
package final class InertDeviceConditions: DeviceConditions {
    package init() {}

    package var thermal: BundleThermal? {
        nil
    }

    package var lowPowerMode: Bool? {
        nil
    }
}

/// The process's own word, read each time a report is made.
@MainActor
package final class SystemDeviceConditions: DeviceConditions {
    private let process: ProcessInfo

    package init(process: ProcessInfo) {
        self.process = process
    }

    package var thermal: BundleThermal? {
        bundleThermal(process.thermalState)
    }

    package var lowPowerMode: Bool? {
        process.isLowPowerModeEnabled
    }
}

/// The system's thermal state in the file's words; a state a newer system
/// adds reads as unknown.
package func bundleThermal(_ state: ProcessInfo.ThermalState) -> BundleThermal? {
    switch state {
    case .nominal: .nominal
    case .fair: .fair
    case .serious: .serious
    case .critical: .critical
    @unknown default: nil
    }
}

/// A device whose conditions a test chose.
@MainActor
package final class FixedDeviceConditions: DeviceConditions {
    package let thermal: BundleThermal?
    package let lowPowerMode: Bool?

    package init(thermal: BundleThermal?, lowPowerMode: Bool?) {
        self.thermal = thermal
        self.lowPowerMode = lowPowerMode
    }
}
