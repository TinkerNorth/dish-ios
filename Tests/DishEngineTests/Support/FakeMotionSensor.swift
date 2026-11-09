// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
@testable import DishEngine

/// The iPhone's motion sensors as the test sets them: present or not, and
/// readings the test feeds by hand while started.
@MainActor
final class FakeMotionSensor: MotionSensor {
    let isAvailable: Bool
    private(set) var starts = 0
    private(set) var stops = 0
    private var reading: (@MainActor (DeviceMotionReading) -> Void)?

    init(available: Bool = true) {
        isAvailable = available
    }

    var running: Bool {
        reading != nil
    }

    func start(_ reading: @escaping @MainActor (DeviceMotionReading) -> Void) {
        starts += 1
        self.reading = reading
    }

    func stop() {
        stops += 1
        reading = nil
    }

    func feed(_ sample: DeviceMotionReading) {
        reading?(sample)
    }
}

/// A clock in uptime nanoseconds the test moves by hand.
@MainActor
final class ManualUptime {
    var nanoseconds: UInt64 = 10_000_000_000

    func read() -> UInt64 {
        nanoseconds
    }

    func advance(ticks: Int) {
        nanoseconds += UInt64(ticks) * 50_000_000
    }
}

/// A phone held still on its side with its top to the left: gravity along
/// its portrait x axis.
let phoneAtRestTopLeft = DeviceMotionReading(
    rotationRate: .zero,
    gravity: MotionAxes(x: -1, y: 0, z: 0),
    userAcceleration: .zero
)
