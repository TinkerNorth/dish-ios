// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What the feedback queue does with each pad's newest command: drive the
/// haptics, the light, the adaptive triggers and the player index. Called on
/// that queue only; the controller bridge's `PadActuators` in production,
/// recorders in tests.
package protocol FeedbackActuators: Sendable {
    func rumble(_ slotId: String, strong: UInt16, weak: UInt16, durationMs: UInt16)
    func lightbar(_ slotId: String, red: UInt8, green: UInt8, blue: UInt8)
    func triggerEffects(_ slotId: String, left: [UInt8], right: [UInt8])
    func playerLeds(_ slotId: String, player: Int)
}

/// Where the slots another source drives are acted on, by the prefix of
/// their ids: that source's queue and its actuators.
struct FeedbackLane {
    let prefix: String
    let queue: DispatchSerialQueue
    let actuators: any FeedbackActuators
}

/// The pads' feedback: one serial queue at the input queue's quality that
/// owns every actuator, and each slot's record of the commands waiting for it.
@MainActor
package final class PadFeedback {
    package nonisolated let queue: DispatchSerialQueue
    private let actuators: any FeedbackActuators
    /// One per slot, made on first use and kept, so a burst that spans a
    /// routing refresh still drains once.
    private var pads: [String: FeedbackPad] = [:]
    private var lanes: [FeedbackLane] = []

    package init(actuators: any FeedbackActuators, queue: DispatchSerialQueue) {
        self.actuators = actuators
        self.queue = queue
    }

    /// The slots whose ids start with `prefix` drain on `queue` into
    /// `actuators` from now on: one hop from the receive loop to the queue
    /// that owns them.
    package func drive(slotsPrefixed prefix: String, on queue: DispatchSerialQueue, with actuators: any FeedbackActuators) {
        lanes.append(FeedbackLane(prefix: prefix, queue: queue, actuators: actuators))
    }

    package func pad(for slotId: String) -> FeedbackPad {
        if let pad = pads[slotId] { return pad }
        let lane = lanes.first { slotId.hasPrefix($0.prefix) }
        let pad = FeedbackPad(slotId: slotId, queue: lane?.queue ?? queue, actuators: lane?.actuators ?? actuators)
        pads[slotId] = pad
        return pad
    }
}

/// One pad's commands on their way to the feedback queue, the newest of each
/// kind: posted from any thread (a receive loop, the main actor), taken on
/// the queue. A post schedules a drain only when none is pending, so a burst
/// costs one hop and the queue applies its last value.
package final class FeedbackPad: Sendable {
    package let slotId: String
    private let queue: DispatchSerialQueue
    private let actuators: any FeedbackActuators
    /// Each word holds the newest command packed with the pending bit, zero
    /// once the queue took it: written by the posters, taken by the queue.
    private let rumbleWord = AtomicWord()
    private let lightbarWord = AtomicWord()
    private let playerWord = AtomicWord()
    private let triggerMail = Mailbox<TriggerEffectsBox>()

    private static let pending: Int64 = 1 << 62

    package init(slotId: String, queue: DispatchSerialQueue, actuators: any FeedbackActuators) {
        self.slotId = slotId
        self.queue = queue
        self.actuators = actuators
    }

    package func post(rumbleStrong strong: UInt16, weak: UInt16, durationMs: UInt16) {
        let packed = Int64(strong) << 32 | Int64(weak) << 16 | Int64(durationMs)
        guard rumbleWord.exchange(Self.pending | packed) & Self.pending == 0 else { return }
        queue.async { self.drainRumble() }
    }

    package func post(lightbarRed red: UInt8, green: UInt8, blue: UInt8) {
        let packed = Int64(red) << 16 | Int64(green) << 8 | Int64(blue)
        guard lightbarWord.exchange(Self.pending | packed) & Self.pending == 0 else { return }
        queue.async { self.drainLightbar() }
    }

    package func post(player: Int) {
        let packed = Int64(UInt32(truncatingIfNeeded: player))
        guard playerWord.exchange(Self.pending | packed) & Self.pending == 0 else { return }
        queue.async { self.drainPlayer() }
    }

    /// One 11-byte DualSense block per trigger, as the game wrote it.
    package func post(triggerEffectsLeft left: [UInt8], right: [UInt8]) {
        guard triggerMail.post(TriggerEffectsBox(left: left, right: right)) else { return }
        queue.async { self.drainTriggerEffects() }
    }

    private func drainRumble() {
        let word = rumbleWord.exchange(0)
        guard word & Self.pending != 0 else { return }
        actuators.rumble(
            slotId,
            strong: UInt16(truncatingIfNeeded: word >> 32),
            weak: UInt16(truncatingIfNeeded: word >> 16),
            durationMs: UInt16(truncatingIfNeeded: word)
        )
    }

    private func drainLightbar() {
        let word = lightbarWord.exchange(0)
        guard word & Self.pending != 0 else { return }
        actuators.lightbar(
            slotId,
            red: UInt8(truncatingIfNeeded: word >> 16),
            green: UInt8(truncatingIfNeeded: word >> 8),
            blue: UInt8(truncatingIfNeeded: word)
        )
    }

    private func drainPlayer() {
        let word = playerWord.exchange(0)
        guard word & Self.pending != 0 else { return }
        actuators.playerLeds(slotId, player: Int(Int32(truncatingIfNeeded: word)))
    }

    private func drainTriggerEffects() {
        guard let box = triggerMail.take() else { return }
        actuators.triggerEffects(slotId, left: box.left, right: box.right)
    }
}

/// One trigger-effects command as the mailbox carries it.
package final class TriggerEffectsBox: Sendable {
    package let left: [UInt8]
    package let right: [UInt8]

    package init(left: [UInt8], right: [UInt8]) {
        self.left = left
        self.right = right
    }
}
