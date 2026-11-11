// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The cold side of the pads' input: it makes a pad's feed when the pad
/// attaches, keeps each pad's dead zones and the routes the main actor
/// resolved, and reads the records for the inspector and the telemetry. Each
/// pad's `PadFeed` is the hot side. On iOS only the main actor reaches the
/// processor (there is no Direct reader), so dish-mac's locked registry is
/// main-actor state here and takes no lock at all.
@MainActor
package final class GamepadInputProcessor {
    package typealias DeviceId = String
    /// Each device's route, as the main actor resolved it.
    package typealias RouteResolver = @MainActor (_ deviceId: DeviceId) -> Route?

    /// Per-axis dead zones: a stick at or below `stickFlat` and a trigger at
    /// or below `triggerFlat` read as zero.
    package struct Deadzones: Equatable {
        package var stickFlat: Int16 = 0
        package var triggerFlat: UInt8 = 0

        package init(stickFlat: Int16 = 0, triggerFlat: UInt8 = 0) {
            self.stickFlat = stickFlat
            self.triggerFlat = triggerFlat
        }
    }

    /// The wire holds motion at or under this rate; a faster sensor is thinned.
    nonisolated static let motionRateLimitHz: UInt64 = 250
    nonisolated static let motionMinIntervalNs: UInt64 = 1_000_000_000 / motionRateLimitHz

    /// When the last report left, on the uptime clock; the keep-awake window
    /// reads it.
    package let lastInputMs = AtomicInt(0)
    /// Every report handed to a sink, for the telemetry's sends.
    package let sent = AtomicCounter()

    private var feeds: [DeviceId: PadFeed] = [:]
    private var deadzones: [DeviceId: Deadzones] = [:]
    private var resolve: RouteResolver = { _ in nil }
    /// What a pad no one tuned reads, from its first report.
    private let untunedZones: Deadzones

    package init(untunedZones: Deadzones = processorZones(.defaults)) {
        self.untunedZones = untunedZones
    }

    // MARK: - Feeds

    /// The device's feed, made with its dead zones and its route on first use.
    package func feed(for deviceId: DeviceId) -> PadFeed {
        if let feed = feeds[deviceId] { return feed }
        let feed = PadFeed(deviceId: deviceId, lastInputMs: lastInputMs, sent: sent)
        feed.useDeadzones(deadzones[deviceId] ?? untunedZones)
        feed.post(route: resolve(deviceId))
        feeds[deviceId] = feed
        return feed
    }

    /// Every feed's route from now on, and the route of every feed made later.
    package func route(_ resolver: @escaping RouteResolver) {
        resolve = resolver
        for (deviceId, feed) in feeds {
            feed.post(route: resolver(deviceId))
        }
    }

    package func setDeadzones(deviceId: DeviceId, _ zones: Deadzones) {
        deadzones[deviceId] = zones
        feeds[deviceId]?.useDeadzones(zones)
    }

    /// The pad left: its feed routes nowhere, and a pad that comes back gets
    /// a fresh one whose counts start over. Its stored zones stay, since the
    /// stores, not the pad, own them.
    package func remove(deviceId: DeviceId) {
        feeds.removeValue(forKey: deviceId)?.post(route: nil)
    }

    // MARK: - Off the hot path

    /// The main actor's battery cadence: through the route it resolved.
    package func publishBattery(deviceId: DeviceId, reading: BatteryReading) {
        guard let route = resolve(deviceId) else { return }
        route.sink.send(battery: reading, slot: route.slot)
    }

    /// Send a released report for every pad, so nothing stays held on the
    /// host when this process stops receiving events.
    package func zeroAndSendAll() {
        for deviceId in feeds.keys {
            guard let route = resolve(deviceId) else { continue }
            sent.increment()
            route.sink.send(.released, slot: route.slot)
        }
    }

    /// What the pad last sent, read off its record; nil for a pad with no feed.
    package func latestInput(_ deviceId: DeviceId) -> LatestInput? {
        feeds[deviceId]?.record.read()
    }

    /// Each pad's published reports and admitted motion samples so far.
    package func tallySnapshot() -> PadTally {
        var tally = PadTally()
        for (deviceId, feed) in feeds {
            let reports = feed.record.reportCount
            let motion = feed.record.motionCount
            let touch = feed.record.touchCount
            if reports > 0 { tally.reports[deviceId] = reports }
            if motion > 0 { tally.motion[deviceId] = motion }
            if touch > 0 { tally.touch[deviceId] = touch }
        }
        return tally
    }
}

/// What each pad has produced so far: its published reports, its admitted
/// motion samples and its touchpad samples.
package struct PadTally: Equatable {
    package var reports: [String: UInt64] = [:]
    package var motion: [String: UInt64] = [:]
    package var touch: [String: UInt64] = [:]
}

/// The stored setting as the processor applies it.
package func processorZones(_ zones: DeadzoneSetting) -> GamepadInputProcessor.Deadzones {
    GamepadInputProcessor.Deadzones(stickFlat: zones.stickFlat, triggerFlat: zones.triggerFlat)
}

// MARK: - Pure conversions

/// deg/s to the wire's int16 at ±2000 deg/s full scale, clamped.
@inline(__always)
func scaleGyro(_ degPerSec: Double) -> Int16 {
    let scaled = (degPerSec / 2000.0) * 32767.0
    return Int16(clamping: Int(scaled.rounded()))
}

/// g to the wire's int16 at ±4 g full scale, clamped.
@inline(__always)
func scaleAccel(_ gValue: Double) -> Int16 {
    let scaled = (gValue / 4.0) * 32767.0
    return Int16(clamping: Int(scaled.rounded()))
}

/// One IMU vector on three axes, in the unit its source reports.
package struct MotionAxes: Equatable {
    package var x: Double
    package var y: Double
    package var z: Double

    package init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    package static let zero = MotionAxes(x: 0, y: 0, z: 0)
}

/// Convert a GCMotion-shaped reading to the wire frame. GameController's
/// `rotationRate` is rad/s with right-hand-rule signs and its `gravity` is
/// the gravitational load vector (a pad at rest reads -1 g up), so the wire's
/// specific force is `userAcceleration - gravity` and the axes map 1:1.
@inline(__always)
func gcMotionToWire(rotationRateRad: MotionAxes, gravity: MotionAxes, userAccel: MotionAxes) -> MotionSample {
    let radToDeg = 180.0 / Double.pi
    return MotionSample(
        gyroX: scaleGyro(rotationRateRad.x * radToDeg),
        gyroY: scaleGyro(rotationRateRad.y * radToDeg),
        gyroZ: scaleGyro(rotationRateRad.z * radToDeg),
        accelX: scaleAccel(userAccel.x - gravity.x),
        accelY: scaleAccel(userAccel.y - gravity.y),
        accelZ: scaleAccel(userAccel.z - gravity.z)
    )
}

/// A finger's wire tracking id bumps on each fresh contact (an up-to-down
/// edge) and holds otherwise; the wrap of a `UInt8` is harmless because only
/// the edge carries information.
@inline(__always)
func nextTouchpadTrackingId(wasActive: Bool, isActive: Bool, current: UInt8) -> UInt8 {
    let freshContact = !wasActive && isActive
    return freshContact ? current &+ 1 : current
}

/// GameController's centre-origin -1...1 touchpad axes to the wire's
/// centre-origin int16 with +y down, so y is negated.
@inline(__always)
func gcTouchpadAxisToWire(x: Float, y: Float) -> (x: Int16, y: Int16) {
    (x: scaleAxis(x, max: 32767), y: scaleAxis(-y, max: 32767))
}

/// Sticks at or below the flat read zero; triggers at or below theirs read
/// zero; buttons pass through.
@inline(__always)
func applyDeadzones(_ report: GamepadReport, _ zones: GamepadInputProcessor.Deadzones) -> GamepadReport {
    let stickFlat = Int32(zones.stickFlat)
    return GamepadReport(
        buttons: report.buttons,
        lt: flattenedTrigger(report.lt, zones.triggerFlat),
        rt: flattenedTrigger(report.rt, zones.triggerFlat),
        lx: flattenedAxis(report.lx, stickFlat),
        ly: flattenedAxis(report.ly, stickFlat),
        rx: flattenedAxis(report.rx, stickFlat),
        ry: flattenedAxis(report.ry, stickFlat)
    )
}

@inline(__always)
private func flattenedAxis(_ axis: Int16, _ flat: Int32) -> Int16 {
    abs(Int32(axis)) <= flat ? 0 : axis
}

@inline(__always)
private func flattenedTrigger(_ trigger: UInt8, _ flat: UInt8) -> UInt8 {
    trigger <= flat ? 0 : trigger
}
