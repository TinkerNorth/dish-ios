// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The client's own view of one host's session in the support file: the
// slots it holds there, the last heartbeat ack's facts, the round trips,
// and what it sent and received by message kind. Counts, never a stream.

import Foundation

/// One slot the session carries.
package struct BundleSessionSlot: Equatable, Encodable {
    package let index: Int
    /// The pad's record id, or nil when no record matched.
    package let record: String?
    /// The type the descriptor asked for: its catalog slug, or the wire
    /// number as text when no catalog is cached.
    package let requestedType: String
    /// The type the host says it materialised, worded the same; nil until
    /// it answered.
    package let appliedType: String?
    /// The backend the host put the pad on; nil where it did not say.
    package let backend: String?
    /// The host's apply result, its protocol word; nil until it answered.
    package let result: String?
    /// The descriptor's touchpad mode; nil where the host kind has none.
    package let touchpadMode: String?

    package init(
        index: Int,
        record: String?,
        requestedType: String,
        appliedType: String?,
        backend: String?,
        result: String?,
        touchpadMode: String?
    ) {
        self.index = index
        self.record = record
        self.requestedType = requestedType
        self.appliedType = appliedType
        self.backend = backend
        self.result = result
        self.touchpadMode = touchpadMode
    }

    private enum CodingKeys: String, CodingKey {
        case index, record, requestedType, appliedType, backend, result, touchpadMode
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(record, forKey: .record)
        try container.encode(requestedType, forKey: .requestedType)
        try container.encode(appliedType, forKey: .appliedType)
        try container.encode(backend, forKey: .backend)
        try container.encode(result, forKey: .result)
        try container.encode(touchpadMode, forKey: .touchpadMode)
    }
}

/// The last enriched heartbeat ack, as it arrived.
package struct BundleAck: Equatable, Encodable {
    package let backendAvailable: Bool
    package let activeControllers: Int
    package let epoch: Int
    package let activeBitmap: UInt16

    package init(backendAvailable: Bool, activeControllers: Int, epoch: Int, activeBitmap: UInt16) {
        self.backendAvailable = backendAvailable
        self.activeControllers = activeControllers
        self.epoch = epoch
        self.activeBitmap = activeBitmap
    }

    private enum CodingKeys: String, CodingKey {
        case backendAvailable, activeControllers, epoch, activeBitmap
    }

    /// The bitmap as four hex digits, "0001" for index 0 alone.
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(backendAvailable, forKey: .backendAvailable)
        try container.encode(activeControllers, forKey: .activeControllers)
        try container.encode(epoch, forKey: .epoch)
        try container.encode(String(format: "%04x", activeBitmap), forKey: .activeBitmap)
    }
}

/// The round trips the client measured; a figure it has no sample for is null.
package struct BundleRtt: Equatable, Encodable {
    package let p50Ms: Double?
    package let p99Ms: Double?
    package let samples: Int?

    package init(p50Ms: Double?, p99Ms: Double?, samples: Int?) {
        self.p50Ms = p50Ms
        self.p99Ms = p99Ms
        self.samples = samples
    }

    private enum CodingKeys: String, CodingKey {
        case p50Ms, p99Ms, samples
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p50Ms, forKey: .p50Ms)
        try container.encode(p99Ms, forKey: .p99Ms)
        try container.encode(samples, forKey: .samples)
    }
}

/// What the client sent, by message kind; a kind the host kind does not
/// count is null.
package struct BundleSent: Equatable, Encodable {
    package let input: UInt64?
    package let motion: UInt64?
    package let battery: UInt64?
    package let pointer: UInt64?
    package let mic: UInt64?
    package let heartbeat: UInt64?

    package init(input: UInt64?, motion: UInt64?, battery: UInt64?, pointer: UInt64?, mic: UInt64?, heartbeat: UInt64?) {
        self.input = input
        self.motion = motion
        self.battery = battery
        self.pointer = pointer
        self.mic = mic
        self.heartbeat = heartbeat
    }

    private enum CodingKeys: String, CodingKey {
        case input, motion, battery, pointer, mic, heartbeat
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(input, forKey: .input)
        try container.encode(motion, forKey: .motion)
        try container.encode(battery, forKey: .battery)
        try container.encode(pointer, forKey: .pointer)
        try container.encode(mic, forKey: .mic)
        try container.encode(heartbeat, forKey: .heartbeat)
    }
}

/// What the client received and opened, by message kind; `other` is a
/// kind this client does not know.
package struct BundleReceived: Equatable, Encodable {
    package let heartbeatAck: UInt64
    package let rumble: UInt64
    package let lightbar: UInt64
    package let triggerEffects: UInt64
    package let playerLeds: UInt64
    package let micLed: UInt64
    package let speaker: UInt64
    package let haptic: UInt64
    package let sessionClose: UInt64
    package let other: UInt64

    package init(
        heartbeatAck: UInt64,
        rumble: UInt64,
        lightbar: UInt64,
        triggerEffects: UInt64,
        playerLeds: UInt64,
        micLed: UInt64,
        speaker: UInt64,
        haptic: UInt64,
        sessionClose: UInt64,
        other: UInt64
    ) {
        self.heartbeatAck = heartbeatAck
        self.rumble = rumble
        self.lightbar = lightbar
        self.triggerEffects = triggerEffects
        self.playerLeds = playerLeds
        self.micLed = micLed
        self.speaker = speaker
        self.haptic = haptic
        self.sessionClose = sessionClose
        self.other = other
    }
}

/// The client's view of one host's session.
package struct BundleSession: Equatable, Encodable {
    package let slots: [BundleSessionSlot]
    /// Nil before the first enriched ack, and for a host kind with none.
    package let ack: BundleAck?
    package let rtt: BundleRtt?
    package let sent: BundleSent?
    /// Nil for a host kind whose messages the client does not count.
    package let received: BundleReceived?

    package init(slots: [BundleSessionSlot], ack: BundleAck?, rtt: BundleRtt?, sent: BundleSent?, received: BundleReceived?) {
        self.slots = slots
        self.ack = ack
        self.rtt = rtt
        self.sent = sent
        self.received = received
    }

    private enum CodingKeys: String, CodingKey {
        case slots, ack, rtt, sent, received
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slots, forKey: .slots)
        try container.encode(ack, forKey: .ack)
        try container.encode(rtt, forKey: .rtt)
        try container.encode(sent, forKey: .sent)
        try container.encode(received, forKey: .received)
    }
}

/// A wire type as the file names it: the catalog's slug for it, or the
/// number as text when the catalog is not cached or names no such type.
package func slotTypeWord(_ type: Int, slugs: [Int: String]) -> String {
    guard let slug = slugs[type], !slug.isEmpty else { return String(type) }
    return slug
}
