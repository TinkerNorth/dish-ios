// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import GameController

/// The return paths (rumble, light bar, adaptive triggers, player index) of
/// `GameControllerInput`.
extension GameControllerInput {

    /// The return paths find a slot's controller by its id: filed here for
    /// the main actor's own reads, and on the feedback queue by identity,
    /// where the actuators look the controller up in the framework's own list.
    func fileController(_ controller: GCController?, for id: String) {
        controllersById[id] = controller
        padActuators.file(controller.map(ObjectIdentifier.init), for: id)
    }

    /// Each command lands on the pad's record, and the feedback queue applies
    /// the newest of each kind. The switches' gates sit upstream; a pad
    /// without the hardware ignores the command there.
    package func applyLightbar(deviceId: String, red: UInt8, green: UInt8, blue: UInt8) {
        feedback.pad(for: deviceId).post(lightbarRed: red, green: green, blue: blue)
    }

    package func applyRumble(deviceId: String, strongMagnitude: UInt16, weakMagnitude: UInt16, durationMs: UInt16) {
        feedback.pad(for: deviceId).post(rumbleStrong: strongMagnitude, weak: weakMagnitude, durationMs: durationMs)
    }

    package func applyTriggerEffects(deviceId: String, left: [UInt8], right: [UInt8]) {
        feedback.pad(for: deviceId).post(triggerEffectsLeft: left, right: right)
    }

    package func applyPlayerLeds(deviceId: String, player: Int) {
        feedback.pad(for: deviceId).post(player: player)
    }

    /// One decoded effect onto one trigger, each shape through the framework
    /// call that renders it.
    nonisolated static func play(_ effect: DualSenseTriggerEffect, on trigger: GCDualSenseAdaptiveTrigger) {
        switch effect {
        case .off:
            trigger.setModeOff()
        case let .feedback(startPosition, strength):
            trigger.setModeFeedbackWithStartPosition(startPosition, resistiveStrength: strength)
        case let .positionalFeedback(strengths):
            trigger.setModeFeedback(resistiveStrengths: positionalStrengths(strengths))
        case let .weapon(startPosition, endPosition, strength):
            trigger.setModeWeaponWithStartPosition(startPosition, endPosition: endPosition, resistiveStrength: strength)
        case let .vibration(startPosition, amplitude, frequency):
            trigger.setModeVibrationWithStartPosition(startPosition, amplitude: amplitude, frequency: frequency)
        case let .positionalVibration(amplitudes, frequency):
            trigger.setModeVibration(amplitudes: positionalAmplitudes(amplitudes), frequency: frequency)
        }
    }

    /// The framework's ten-zone struct from an array; a short array leaves
    /// the remaining zones at zero.
    nonisolated static func positionalStrengths(_ values: [Float]) -> GCDualSenseAdaptiveTrigger.PositionalResistiveStrengths {
        var out = GCDualSenseAdaptiveTrigger.PositionalResistiveStrengths()
        withUnsafeMutableBytes(of: &out.values) { raw in
            let zones = raw.bindMemory(to: Float.self)
            for (index, value) in values.prefix(zones.count).enumerated() {
                zones[index] = value
            }
        }
        return out
    }

    nonisolated static func positionalAmplitudes(_ values: [Float]) -> GCDualSenseAdaptiveTrigger.PositionalAmplitudes {
        var out = GCDualSenseAdaptiveTrigger.PositionalAmplitudes()
        withUnsafeMutableBytes(of: &out.values) { raw in
            let zones = raw.bindMemory(to: Float.self)
            for (index, value) in values.prefix(zones.count).enumerated() {
                zones[index] = value
            }
        }
        return out
    }

    /// Players one to four light the framework's four patterns; anything
    /// else clears them.
    nonisolated static func playerIndex(for player: Int) -> GCControllerPlayerIndex {
        switch player {
        case 1: .index1
        case 2: .index2
        case 3: .index3
        case 4: .index4
        default: .indexUnset
        }
    }
}
