// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// One session's datagrams by message kind, for the support file: each a
/// relaxed tally the send path and the receive loop bump without a lock,
/// a hop or an allocation, and the main actor reads when a report is made.
package final class WireTally: Sendable {
    private let input = AtomicCounter()
    private let motion = AtomicCounter()
    private let battery = AtomicCounter()
    private let pointer = AtomicCounter()
    private let heartbeat = AtomicCounter()
    private let heartbeatAck = AtomicCounter()
    private let rumble = AtomicCounter()
    private let lightbar = AtomicCounter()
    private let triggerEffects = AtomicCounter()
    private let playerLeds = AtomicCounter()
    private let micLed = AtomicCounter()
    private let speaker = AtomicCounter()
    private let haptic = AtomicCounter()
    private let sessionClose = AtomicCounter()
    private let other = AtomicCounter()

    package init() {}

    /// A datagram handed to the socket. This client sends no microphone audio.
    func countSent(_ msgType: UInt16) {
        switch msgType {
        case ProtocolConstants.msgInput: input.increment()
        case ProtocolConstants.msgMotion: motion.increment()
        case ProtocolConstants.msgBattery: battery.increment()
        case ProtocolConstants.msgTouchpad: pointer.increment()
        case ProtocolConstants.msgHeartbeat: heartbeat.increment()
        default: break
        }
    }

    /// A datagram opened, whether or not this client acts on its kind.
    func countReceived(_ msgType: UInt16) {
        switch msgType {
        case ProtocolConstants.msgHeartbeatAck: heartbeatAck.increment()
        case ProtocolConstants.msgRumble: rumble.increment()
        case ProtocolConstants.msgLightbar: lightbar.increment()
        case ProtocolConstants.msgTriggerEffects: triggerEffects.increment()
        case ProtocolConstants.msgPlayerLeds: playerLeds.increment()
        case ProtocolConstants.msgMicLed: micLed.increment()
        case ProtocolConstants.msgSpeakerAudio: speaker.increment()
        case ProtocolConstants.msgHapticAudio: haptic.increment()
        case ProtocolConstants.msgSessionClose: sessionClose.increment()
        default: other.increment()
        }
    }

    /// A new session generation counts from zero, as the other counters do.
    func reset() {
        for counter in [input, motion, battery, pointer, heartbeat, heartbeatAck, rumble, lightbar] {
            counter.reset()
        }
        for counter in [triggerEffects, playerLeds, micLed, speaker, haptic, sessionClose, other] {
            counter.reset()
        }
    }

    package var sent: BundleSent {
        BundleSent(
            input: input.current(),
            motion: motion.current(),
            battery: battery.current(),
            pointer: pointer.current(),
            mic: 0,
            heartbeat: heartbeat.current()
        )
    }

    package var received: BundleReceived {
        BundleReceived(
            heartbeatAck: heartbeatAck.current(),
            rumble: rumble.current(),
            lightbar: lightbar.current(),
            triggerEffects: triggerEffects.current(),
            playerLeds: playerLeds.current(),
            micLed: micLed.current(),
            speaker: speaker.current(),
            haptic: haptic.current(),
            sessionClose: sessionClose.current(),
            other: other.current()
        )
    }
}
