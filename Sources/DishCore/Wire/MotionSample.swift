// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

/// One IMU reading on the wire's scale: gyro at ±2000 deg/s and accel at
/// ±4 g over int16, right-handed with +X right, +Y up, +Z toward the player.
package struct MotionSample: Equatable {
    package let gyroX: Int16
    package let gyroY: Int16
    package let gyroZ: Int16
    package let accelX: Int16
    package let accelY: Int16
    package let accelZ: Int16

    package init(gyroX: Int16, gyroY: Int16, gyroZ: Int16, accelX: Int16, accelY: Int16, accelZ: Int16) {
        self.gyroX = gyroX
        self.gyroY = gyroY
        self.gyroZ = gyroZ
        self.accelX = accelX
        self.accelY = accelY
        self.accelZ = accelZ
    }
}
