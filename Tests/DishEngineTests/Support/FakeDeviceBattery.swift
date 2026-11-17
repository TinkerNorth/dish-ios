// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
@testable import DishEngine

/// The iPhone's battery as the test sets it: a reading, or none.
@MainActor
final class FakeDeviceBattery: DeviceBattery {
    var reading: BatteryReading?

    init(_ reading: BatteryReading? = nil) {
        self.reading = reading
    }
}
