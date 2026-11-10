// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What the satellite client's receive loop calls for each message it
/// opens, swapped whole: the connection's feedback routes for the four
/// return paths, and the close relay. Whoever sets one builds a new set and
/// posts it, and the loop takes the newest before its next dispatch. The
/// audio frames have no handler: iOS gives apps no pad speaker.
struct ReceiveHandlers {
    var feedback: FeedbackRoutes?
    var sessionClose: (@Sendable (CloseReason) -> Void)?
}

/// One set as the mailbox carries it to the receive loop.
final class ReceiveHandlersBox: Sendable {
    let handlers: ReceiveHandlers

    init(_ handlers: ReceiveHandlers) {
        self.handlers = handlers
    }
}

/// The enriched heartbeat ack in one word, so the receive loop stores it and
/// the alive tick reads it with no lock: a presence bit, then each field.
extension HeartbeatAck {
    private static let present: Int64 = 1 << 48
    private static let backend: Int64 = 1 << 40

    /// Nil for the empty word, which no stored ack packs to.
    init?(packed word: Int64) {
        guard word & Self.present != 0 else { return nil }
        self.init(
            backendAvailable: word & Self.backend != 0,
            activeCount: UInt8(truncatingIfNeeded: word >> 32),
            epoch: UInt16(truncatingIfNeeded: word >> 16),
            bitmap: UInt16(truncatingIfNeeded: word)
        )
    }

    var packed: Int64 {
        Self.present | (backendAvailable ? Self.backend : 0) | Int64(activeCount) << 32 | Int64(epoch) << 16 | Int64(bitmap)
    }
}

/// The wire's battery for a reading: the level, or the unknown marker for a
/// pad that reports only its charge state, and the state as its status
/// byte. Nil for a reading that says nothing, which the wire never carries.
func wireBattery(_ reading: BatteryReading) -> (level: UInt8, status: BatteryStatus)? {
    let status = wireBatteryStatus(reading.state)
    guard reading.level != nil || status != .unknown else { return nil }
    let level = reading.level.map { UInt8(clamping: $0) } ?? ProtocolConstants.batteryLevelUnknown
    return (level, status)
}

func wireBatteryStatus(_ state: BatteryChargeState) -> BatteryStatus {
    switch state {
    case .unknown: .unknown
    case .discharging: .discharging
    case .charging: .charging
    case .full: .full
    }
}
