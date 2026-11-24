// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import CoreHaptics
import Foundation
import GameController

/// Per-controller haptic actuator: `GCController.haptics` and two
/// `CHHapticEngine`s, one per motor of a pair: the handles, the strong
/// (low-frequency) motor at `.leftHandle` and the weak one at `.rightHandle`,
/// so one satellite rumble drives both; or the triggers, `.leftTrigger` and
/// `.rightTrigger`, which only the bench drives. Vibration only: the light
/// bar has its own return path. It runs on the feedback queue, which owns it.
///
/// Engines are kept started: starting one per command adds ~5–10 ms. Each
/// motor keeps the player for the level it is playing and restarts that same
/// player when a command repeats the level (SDL's rule: a repeated rumble is
/// not a new one); only a new level builds a new pattern and player, and a
/// zero level stops the motor at once.
///
/// A controller that exposes no haptics (legacy MFi pads, some PS3
/// adapters) makes `init?` fail, and the caller skips actuation.
final class RumbleActuator {
    private let controller: GCController
    private var leftMotor: HapticMotor?
    private var rightMotor: HapticMotor?

    /// Nil when the controller vends no engine at either motor of the pair.
    init?(controller: GCController, pair: MotorPair) {
        guard let haptics = controller.haptics else { return nil }
        self.controller = controller
        leftMotor = haptics.createEngine(withLocality: pair.left).flatMap(HapticMotor.init(engine:))
        rightMotor = haptics.createEngine(withLocality: pair.right).flatMap(HapticMotor.init(engine:))
        if leftMotor == nil, rightMotor == nil {
            return nil
        }
    }

    func shutdown() {
        leftMotor?.shutdown()
        rightMotor?.shutdown()
        leftMotor = nil
        rightMotor = nil
    }

    /// The longest one packet may run the motors. The satellite owns a held
    /// level: it re-sends it every 200 ms, well inside the 500 ms it stamps,
    /// and sends the stop itself, so the duration is only the safety net
    /// against a dead host, and a continuous packet (`durationMs == 0`) holds
    /// for this long too rather than until the next packet.
    static let maxHoldMs: UInt16 = 1500

    /// How long a packet runs the motors.
    static func holdSeconds(durationMs: UInt16) -> TimeInterval {
        let capped = durationMs == 0 ? maxHoldMs : min(durationMs, maxHoldMs)
        return TimeInterval(capped) / 1000.0
    }

    /// Each motor at its level, normalised from the wire's 0...65535 to
    /// CoreHaptics' 0...1: on the handles, the strong motor is the left.
    func apply(left: UInt16, right: UInt16, durationMs: UInt16) {
        let duration = Self.holdSeconds(durationMs: durationMs)
        leftMotor?.drive(magnitude: left, duration: duration)
        rightMotor?.drive(magnitude: right, duration: duration)
    }
}

/// The pair of motors an actuator drives, by the localities GameController
/// names for them (`GCDeviceHapticsLocality.h`).
enum MotorPair {
    case handles
    case triggers

    var left: GCHapticsLocality {
        switch self {
        case .handles: .leftHandle
        case .triggers: .leftTrigger
        }
    }

    var right: GCHapticsLocality {
        switch self {
        case .handles: .rightHandle
        case .triggers: .rightTrigger
        }
    }
}

/// Whether this iPhone has the Taptic Engine the on-screen controller's
/// rumble plays on; false in the simulator.
package func phoneHasHaptics() -> Bool {
    CHHapticEngine.capabilitiesForHardware().supportsHaptics
}

/// The on-screen controller's rumble on the iPhone's own Taptic Engine. The
/// phone has one actuator, so it plays the stronger of the two motors. It
/// runs on the feedback queue, as a pad's actuator does.
final class PhoneRumble {
    private let motor: HapticMotor

    /// Nil on an iPhone without haptics, and in the simulator.
    init?() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine = try? CHHapticEngine(),
              let motor = HapticMotor(engine: engine) else { return nil }
        self.motor = motor
    }

    func apply(strong: UInt16, weak: UInt16, durationMs: UInt16) {
        motor.drive(
            magnitude: phoneRumbleMagnitude(strong: strong, weak: weak),
            duration: RumbleActuator.holdSeconds(durationMs: durationMs)
        )
    }
}

/// One actuator for two motors: the stronger one is what the hand feels.
func phoneRumbleMagnitude(strong: UInt16, weak: UInt16) -> UInt16 {
    max(strong, weak)
}

/// One motor's level: what its player plays, and for how long.
struct MotorLevel: Equatable {
    let magnitude: UInt16
    let duration: TimeInterval
}

/// What a motor does with one command.
enum MotorStep: Equatable {
    /// The level repeats: the player it has starts again.
    case restart
    /// A new level: a new pattern and player.
    case replace(MotorLevel)
    /// Zero: the motor stops.
    case stop
}

/// The step for a command of `magnitude` held for `duration` while the
/// motor plays `playing` (nil while it has no player).
func motorStep(playing: MotorLevel?, magnitude: UInt16, duration: TimeInterval) -> MotorStep {
    guard magnitude > 0 else { return .stop }
    let level = MotorLevel(magnitude: magnitude, duration: duration)
    return level == playing ? .restart : .replace(level)
}

/// One motor's engine and the player for the level it plays.
final class HapticMotor {
    private let engine: CHHapticEngine
    private var player: CHHapticPatternPlayer?
    private var playing: MotorLevel?

    init?(engine: CHHapticEngine) {
        // Auto-restart after the system reclaims the engine's resources;
        // without it the next wave of rumble after a long idle fails.
        engine.resetHandler = { [weak engine] in
            try? engine?.start()
        }
        do {
            try engine.start()
        } catch {
            return nil
        }
        self.engine = engine
    }

    func shutdown() {
        silence()
        engine.stop(completionHandler: nil)
    }

    func drive(magnitude: UInt16, duration: TimeInterval) {
        switch motorStep(playing: player == nil ? nil : playing, magnitude: magnitude, duration: duration) {
        case .stop:
            silence()
        case .restart:
            try? player?.stop(atTime: CHHapticTimeImmediate)
            start()
        case let .replace(level):
            silence()
            player = makePlayer(level)
            playing = level
            start()
        }
    }

    /// A reset engine invalidates its players: one that fails to start is
    /// dropped, and the next command builds a fresh one.
    private func start() {
        do {
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            player = nil
        }
    }

    private func silence() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        playing = nil
    }

    /// `hapticContinuous` drives a motor for the whole duration; sharpness 0.5
    /// is neutral, and devices that cannot shape the spectrum ignore it.
    private func makePlayer(_ level: MotorLevel) -> CHHapticPatternPlayer? {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(level.magnitude) / 65535.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: level.duration
        )
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { return nil }
        return try? engine.makePlayer(with: pattern)
    }
}
