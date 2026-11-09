// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import CoreMotion
import DishCore
import Foundation

/// One reading of the iPhone's own motion sensors in the device's frame:
/// rotation in rad/s, gravity and the user's acceleration in g, as
/// `CMDeviceMotion` reports them.
package struct DeviceMotionReading: Equatable {
    package let rotationRate: MotionAxes
    package let gravity: MotionAxes
    package let userAcceleration: MotionAxes

    package init(rotationRate: MotionAxes, gravity: MotionAxes, userAcceleration: MotionAxes) {
        self.rotationRate = rotationRate
        self.gravity = gravity
        self.userAcceleration = userAcceleration
    }
}

/// The seam to the iPhone's motion sensors: whether it has them, and a
/// stream of readings on the main actor while started. `DeviceMotionSensor`
/// is the production one; a test hands the model its own.
@MainActor
package protocol MotionSensor: AnyObject {
    var isAvailable: Bool { get }
    func start(_ reading: @escaping @MainActor (DeviceMotionReading) -> Void)
    func stop()
}

/// The iPhone's device motion through CoreMotion, delivered on the main
/// queue: the on-screen pad's one publishing thread.
@MainActor
package final class DeviceMotionSensor: MotionSensor {
    /// The wire holds motion at 250 Hz; the phone reads at 100.
    private static let intervalSeconds: TimeInterval = 0.01
    private let manager = CMMotionManager()

    package init() {}

    package var isAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    package func start(_ reading: @escaping @MainActor (DeviceMotionReading) -> Void) {
        manager.deviceMotionUpdateInterval = Self.intervalSeconds
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let sample = deviceMotionReading(motion)
            MainActor.assumeIsolated { reading(sample) }
        }
    }

    package func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

private func deviceMotionReading(_ motion: CMDeviceMotion) -> DeviceMotionReading {
    DeviceMotionReading(
        rotationRate: MotionAxes(x: motion.rotationRate.x, y: motion.rotationRate.y, z: motion.rotationRate.z),
        gravity: MotionAxes(x: motion.gravity.x, y: motion.gravity.y, z: motion.gravity.z),
        userAcceleration: MotionAxes(x: motion.userAcceleration.x, y: motion.userAcceleration.y, z: motion.userAcceleration.z)
    )
}

/// Which way the iPhone lies on its side, named by where its top points.
package enum LandscapeSide: Equatable {
    case topLeft
    case topRight
}

/// How far gravity must lean along the phone's long side before the side
/// flips, so a phone flat on a table keeps the side it had, as iOS keeps
/// its interface orientation.
let landscapeFlipGravity = 0.5

/// The side the phone lies on: gravity pulls toward its right edge (in
/// portrait terms) when its top points left, toward its left edge when its
/// top points right.
package func landscapeSide(previous: LandscapeSide, gravityX: Double) -> LandscapeSide {
    guard abs(gravityX) >= landscapeFlipGravity else { return previous }
    return gravityX < 0 ? .topLeft : .topRight
}

/// The phone's axes turned into the pad's: +X right, +Y up, +Z toward the
/// player, for a phone held on its side as a pad is held.
package func padAxes(_ axes: MotionAxes, side: LandscapeSide) -> MotionAxes {
    switch side {
    case .topLeft: MotionAxes(x: -axes.y, y: axes.x, z: axes.z)
    case .topRight: MotionAxes(x: axes.y, y: -axes.x, z: axes.z)
    }
}

/// The phone's reading as the wire's motion sample, the pad's frame on the
/// side the phone lies on; CoreMotion's units and signs are GameController's.
package func phoneMotionToWire(_ reading: DeviceMotionReading, side: LandscapeSide) -> MotionSample {
    gcMotionToWire(
        rotationRateRad: padAxes(reading.rotationRate, side: side),
        gravity: padAxes(reading.gravity, side: side),
        userAccel: padAxes(reading.userAcceleration, side: side)
    )
}
