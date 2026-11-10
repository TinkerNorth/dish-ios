// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The ENet wire the Moonlight control stream rides on, the subset a client
// needs: the connect handshake, reliable send and receive on one channel,
// acknowledgements, ping and disconnect. Ported to Swift from the MIT
// cgutman/enet C source at the commit Wolf pins (protocol.h, protocol.c,
// peer.c); see THIRD_PARTY.md. Every multi-byte field is big-endian.

import Foundation

package enum EnetProtocol {
    package static let commandAcknowledge: UInt8 = 1
    package static let commandConnect: UInt8 = 2
    package static let commandVerifyConnect: UInt8 = 3
    package static let commandDisconnect: UInt8 = 4
    package static let commandPing: UInt8 = 5
    package static let commandSendReliable: UInt8 = 6
    package static let commandSendUnreliable: UInt8 = 7
    package static let commandSendFragment: UInt8 = 8
    package static let commandSendUnsequenced: UInt8 = 9
    package static let commandBandwidthLimit: UInt8 = 10
    package static let commandThrottleConfigure: UInt8 = 11
    package static let commandSendUnreliableFragment: UInt8 = 12
    package static let commandMask: UInt8 = 0x0F
    package static let flagAcknowledge: UInt8 = 1 << 7
    package static let flagUnsequenced: UInt8 = 1 << 6

    /// The datagram header's 16-bit word: the peer id in the low twelve bits,
    /// the session id above them, and the two flags on top.
    package static let headerFlagCompressed: UInt16 = 1 << 14
    package static let headerFlagSentTime: UInt16 = 1 << 15
    package static let headerSessionMask: UInt16 = 3 << 12
    package static let headerSessionShift: UInt16 = 12
    package static let maximumPeerId: UInt16 = 0xFFF
    /// A session id neither side has assigned yet.
    package static let sessionIdUnset: UInt8 = 0xFF
    /// Connect, ping and disconnect ride the system channel; data rides channel 0.
    package static let systemChannel: UInt8 = 0xFF
    package static let dataChannel: UInt8 = 0
    package static let channelCount: UInt32 = 1

    package static let minimumMtu: UInt32 = 576
    package static let maximumMtu: UInt32 = 4096
    package static let minimumWindowSize: UInt32 = 4096
    package static let maximumWindowSize: UInt32 = 65536
    package static let defaultMtu: UInt32 = 1400
    package static let throttleInterval: UInt32 = 5000
    package static let throttleAcceleration: UInt32 = 2
    package static let throttleDeceleration: UInt32 = 2

    /// The peer liveness numbers the host on the other end uses too, so one
    /// side never gives up while the other still thinks the link is healthy.
    package static let pingIntervalMs: Int64 = 500
    package static let defaultRoundTripTimeMs: Int64 = 500
    package static let timeoutLimit = 32
    package static let timeoutMinimumMs: Int64 = 5000
    package static let timeoutMaximumMs: Int64 = 30000
    /// Reliable sequence numbers live in windows of this many, sixteen of
    /// them around the ring, and a command this many windows ahead is discarded.
    package static let reliableWindowSize: UInt16 = 0x1000
    package static let reliableWindows: UInt16 = 16
    package static let freeReliableWindows: UInt16 = 8

    package static let commandHeaderLength = 4
    package static let acknowledgeLength = 8
    package static let connectLength = 48
    package static let verifyConnectLength = 44
    package static let disconnectLength = 8
    package static let pingLength = 4
    package static let sendReliableHeaderLength = 6
    package static let sendUnreliableHeaderLength = 8
    package static let sendUnsequencedHeaderLength = 8
    package static let sendFragmentHeaderLength = 24
    package static let bandwidthLimitLength = 12
    package static let throttleConfigureLength = 16

    /// The fixed on-wire size of one command, protocol.c's `commandSizes`
    /// table exactly; the SEND_* sizes are the header alone, a counted
    /// payload follows. Every number is here, the ones this client never
    /// sends included: a peer bundles several commands into one datagram, so
    /// a command that cannot be measured costs every command behind it.
    package static func size(ofCommand number: UInt8) -> Int? {
        switch number {
        case commandAcknowledge: acknowledgeLength
        case commandConnect: connectLength
        case commandVerifyConnect: verifyConnectLength
        case commandDisconnect: disconnectLength
        case commandPing: pingLength
        case commandSendReliable: sendReliableHeaderLength
        case commandSendUnreliable: sendUnreliableHeaderLength
        case commandSendFragment, commandSendUnreliableFragment: sendFragmentHeaderLength
        case commandSendUnsequenced: sendUnsequencedHeaderLength
        case commandBandwidthLimit: bandwidthLimitLength
        case commandThrottleConfigure: throttleConfigureLength
        default: nil
        }
    }

    /// Where, inside a SEND_* command's fixed header, the u16 count of the
    /// payload that follows it sits; nil for a command that carries none.
    package static func dataLengthOffset(ofCommand number: UInt8) -> Int? {
        switch number {
        case commandSendReliable: commandHeaderLength
        case commandSendUnreliable, commandSendUnsequenced, commandSendFragment, commandSendUnreliableFragment: commandHeaderLength + 2
        default: nil
        }
    }
}

/// One command's header: the command byte, the channel, the reliable sequence.
package struct EnetCommandHeader: Equatable {
    package let command: UInt8
    package let channel: UInt8
    package let reliableSequence: UInt16

    package var number: UInt8 {
        command & EnetProtocol.commandMask
    }

    package var wantsAcknowledge: Bool {
        command & EnetProtocol.flagAcknowledge != 0
    }
}

/// What the datagram header says about the whole datagram.
package struct EnetDatagramHeader: Equatable {
    package let peerId: UInt16
    package let sessionId: UInt8
    package let sentTime: UInt16?
    package let compressed: Bool
}

package enum EnetWire {
    /// The outer header: before VERIFY_CONNECT the peer field is 0xFFF with no
    /// session bits; after it, the host's id for us and its session id.
    package static func header(outgoingPeerId: UInt16, outgoingSessionId: UInt8, sentTime: UInt16) -> ByteWriter {
        var writer = ByteWriter(capacity: 64)
        let assigned = outgoingPeerId < EnetProtocol.maximumPeerId
        var word = outgoingPeerId & EnetProtocol.maximumPeerId
        if assigned { word |= (UInt16(outgoingSessionId) << EnetProtocol.headerSessionShift) & EnetProtocol.headerSessionMask }
        word |= EnetProtocol.headerFlagSentTime
        writer.u16BE(word)
        writer.u16BE(sentTime)
        return writer
    }

    package static func commandHeader(_ writer: inout ByteWriter, command: UInt8, channel: UInt8, reliableSequence: UInt16) {
        writer.u8(command)
        writer.u8(channel)
        writer.u16BE(reliableSequence)
    }

    package static func readDatagramHeader(_ reader: inout ByteReader) -> EnetDatagramHeader? {
        guard let word = reader.u16BE() else { return nil }
        let compressed = word & EnetProtocol.headerFlagCompressed != 0
        let hasSentTime = word & EnetProtocol.headerFlagSentTime != 0
        var sentTime: UInt16?
        if hasSentTime {
            guard let time = reader.u16BE() else { return nil }
            sentTime = time
        }
        let sessionId = UInt8((word & EnetProtocol.headerSessionMask) >> EnetProtocol.headerSessionShift)
        return EnetDatagramHeader(
            peerId: word & EnetProtocol.maximumPeerId,
            sessionId: sessionId,
            sentTime: sentTime,
            compressed: compressed
        )
    }

    package static func readCommandHeader(_ reader: inout ByteReader) -> EnetCommandHeader? {
        guard let command = reader.u8(), let channel = reader.u8(), let sequence = reader.u16BE() else { return nil }
        return EnetCommandHeader(command: command, channel: channel, reliableSequence: sequence)
    }
}
