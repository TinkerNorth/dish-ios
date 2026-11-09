// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import GameController

/// The controllers as the feedback queue drives them: each slot's controller
/// as the main actor last filed it, and the rumble actuator made for it on
/// first use. An actor whose executor is the feedback queue, so its state is
/// the queue's and the compiler knows it: a drain on that queue enters it
/// without a hop, and nothing here waits on the main thread.
///
/// A `GCController` is not `Sendable`, so the main actor files a slot's
/// controller by identity and the queue finds the object in the framework's
/// own list; the controller never crosses from one isolation to the other.
package actor PadActuators: FeedbackActuators {
    package nonisolated let queue: DispatchSerialQueue
    private var controllers: [String: GCController] = [:]
    private var rumblers: [String: RumbleActuator] = [:]
    private var phone: PhoneRumble?

    package nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    package init(queue: DispatchSerialQueue) {
        self.queue = queue
    }

    /// Files the slot's controller, or none once it goes, on the queue.
    package nonisolated func file(_ identity: ObjectIdentifier?, for slotId: String) {
        queue.async {
            self.assumeIsolated { $0.store(identity, for: slotId) }
        }
    }

    /// The queue's half: a different controller under the slot drops the
    /// old one's engines.
    private func store(_ identity: ObjectIdentifier?, for slotId: String) {
        let controller = identity.flatMap(Self.attachedController)
        guard controllers[slotId] !== controller else { return }
        rumblers.removeValue(forKey: slotId)?.shutdown()
        controllers[slotId] = controller
    }

    private static func attachedController(_ identity: ObjectIdentifier) -> GCController? {
        GCController.controllers().first { ObjectIdentifier($0) == identity }
    }

    // MARK: - The feedback queue's actuators

    /// The on-screen controller rumbles the iPhone; a pad its own motors.
    package nonisolated func rumble(_ slotId: String, strong: UInt16, weak: UInt16, durationMs: UInt16) {
        guard slotId != onScreenSlotId else {
            return assumeIsolated { $0.phoneRumbler()?.apply(strong: strong, weak: weak, durationMs: durationMs) }
        }
        assumeIsolated { $0.rumbler(for: slotId)?.apply(strong: strong, weak: weak, durationMs: durationMs) }
    }

    package nonisolated func lightbar(_ slotId: String, red: UInt8, green: UInt8, blue: UInt8) {
        assumeIsolated { $0.paint(slotId, red: red, green: green, blue: blue) }
    }

    package nonisolated func triggerEffects(_ slotId: String, left: [UInt8], right: [UInt8]) {
        let leftEffect = DualSenseTriggerEffect.decode(left)
        let rightEffect = DualSenseTriggerEffect.decode(right)
        assumeIsolated { $0.playTriggers(slotId, left: leftEffect, right: rightEffect) }
    }

    package nonisolated func playerLeds(_ slotId: String, player: Int) {
        assumeIsolated { $0.controllers[slotId]?.playerIndex = GameControllerInput.playerIndex(for: player) }
    }

    private func paint(_ slotId: String, red: UInt8, green: UInt8, blue: UInt8) {
        controllers[slotId]?.light?.color = GCColor(red: Float(red) / 255, green: Float(green) / 255, blue: Float(blue) / 255)
    }

    private func playTriggers(_ slotId: String, left: DualSenseTriggerEffect, right: DualSenseTriggerEffect) {
        guard let dualSense = controllers[slotId]?.extendedGamepad as? GCDualSenseGamepad else { return }
        GameControllerInput.play(left, on: dualSense.leftTrigger)
        GameControllerInput.play(right, on: dualSense.rightTrigger)
    }

    /// Made on the first rumble; an iPhone without haptics drops it.
    private func phoneRumbler() -> PhoneRumble? {
        if let phone { return phone }
        phone = PhoneRumble()
        return phone
    }

    /// A pad without haptics takes no actuator and its rumble is dropped.
    private func rumbler(for slotId: String) -> RumbleActuator? {
        if let existing = rumblers[slotId] { return existing }
        guard let controller = controllers[slotId], let fresh = RumbleActuator(controller: controller) else { return nil }
        rumblers[slotId] = fresh
        return fresh
    }
}
