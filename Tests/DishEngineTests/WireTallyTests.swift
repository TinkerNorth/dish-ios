// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// A session's datagrams by kind: each send and each opened message lands
/// on its kind's tally, a kind this client does not know on `other`, and a
/// new generation counts from zero.
final class WireTallyTests: XCTestCase {

    func testEachSentKindLandsOnItsOwnTally() {
        let tally = WireTally()
        tally.countSent(ProtocolConstants.msgInput)
        tally.countSent(ProtocolConstants.msgInput)
        tally.countSent(ProtocolConstants.msgMotion)
        tally.countSent(ProtocolConstants.msgBattery)
        tally.countSent(ProtocolConstants.msgTouchpad)
        tally.countSent(ProtocolConstants.msgHeartbeat)
        XCTAssertEqual(tally.sent, BundleSent(input: 2, motion: 1, battery: 1, pointer: 1, mic: 0, heartbeat: 1))
    }

    func testEachReceivedKindLandsOnItsOwnTallyAndAnUnknownOneOnOther() {
        let tally = WireTally()
        let kinds = [
            ProtocolConstants.msgHeartbeatAck, ProtocolConstants.msgRumble, ProtocolConstants.msgRumble,
            ProtocolConstants.msgLightbar, ProtocolConstants.msgTriggerEffects, ProtocolConstants.msgPlayerLeds,
            ProtocolConstants.msgMicLed, ProtocolConstants.msgSpeakerAudio, ProtocolConstants.msgHapticAudio,
            ProtocolConstants.msgSessionClose, 0x7777
        ]
        for kind in kinds {
            tally.countReceived(kind)
        }
        XCTAssertEqual(tally.received, BundleReceived(
            heartbeatAck: 1,
            rumble: 2,
            lightbar: 1,
            triggerEffects: 1,
            playerLeds: 1,
            micLed: 1,
            speaker: 1,
            haptic: 1,
            sessionClose: 1,
            other: 1
        ))
    }

    func testANewGenerationCountsFromZero() {
        let tally = WireTally()
        tally.countSent(ProtocolConstants.msgInput)
        tally.countReceived(ProtocolConstants.msgRumble)
        tally.reset()
        XCTAssertEqual(tally.sent.input, 0)
        XCTAssertEqual(tally.received.rumble, 0)
    }
}
