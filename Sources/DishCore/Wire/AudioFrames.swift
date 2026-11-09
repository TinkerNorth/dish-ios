// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// Controller audio on the wire (contract §Controller audio, §Controller
// haptics): the emulated pad's OWN audio endpoints, never the host's game
// audio. MIC_AUDIO 0x0012 goes up, SPEAKER_AUDIO 0x0013 and HAPTIC_AUDIO
// 0x0015 come down, each `ctrlIdx(1) + seq(u16 BE) + one Opus packet`, and
// MIC_LED 0x0014 reports the lamp state the game asked for. The format is
// fixed, never negotiated.

import Foundation

package enum AudioWire {
    package static let sampleRate = 48000
    package static let frameMs = 20
    /// 20 ms at 48 kHz, per channel.
    package static let samplesPerChannel = 960
    package static let micChannels = 1
    package static let speakerChannels = 2
    package static let hapticChannels = 2
    /// ~32 kbps VBR, Opus VOIP, in-band FEC, DTX on.
    package static let micBitrate = 32000
    /// ~96 kbps VBR, Opus AUDIO, in-band FEC, for both down lanes.
    package static let speakerBitrate = 96000
    /// The server drops MIC_AUDIO beyond this per controller; nominal is 50.
    package static let micMaxPacketsPerSecond = 75
    /// The receiver's reorder window, in frames (40 ms).
    package static let reorderWindowFrames = 2
    /// ctrlIdx(1) + seq(2); the Opus packet is at least one byte.
    package static let headerBytes = 3
}

/// One audio message either way: which controller, the wrapping sequence
/// number, and exactly one self-delimiting Opus packet.
package struct AudioFrame: Equatable {
    package let controllerIndex: UInt8
    package let seq: UInt16
    package let opus: Data

    package init(controllerIndex: UInt8, seq: UInt16, opus: Data) {
        self.controllerIndex = controllerIndex
        self.seq = seq
        self.opus = opus
    }

    /// Parse `ctrlIdx(1) + seq(u16 BE) + opus(>= 1)`; nil when the header is
    /// short or no Opus byte follows it (a silence frame is a one-byte DTX
    /// packet, never an empty one).
    package static func parse(_ payload: Data) -> AudioFrame? {
        guard payload.count > AudioWire.headerBytes else { return nil }
        let opus = Data(payload[(payload.startIndex + AudioWire.headerBytes)...])
        return AudioFrame(controllerIndex: payload.byte(0), seq: payload.u16BE(1), opus: opus)
    }

    /// The payload's length: the header and the Opus bytes.
    package var payloadCount: Int {
        AudioWire.headerBytes + opus.count
    }

    /// `payload` written into the first `payloadCount` bytes of `out`.
    package func writePayload(into out: UnsafeMutableRawBufferPointer) {
        out[0] = controllerIndex
        out[1] = UInt8(seq >> 8)
        out[2] = UInt8(seq & 0xFF)
        UnsafeMutableRawBufferPointer(rebasing: out[AudioWire.headerBytes...]).copyBytes(from: opus)
    }

    /// The payload behind the inner header.
    package var payload: Data {
        Data([controllerIndex, UInt8(seq >> 8), UInt8(seq & 0xFF)]) + opus
    }
}

/// The mic-mute lamp state the game asked for (MIC_LED 0x0014), advisory:
/// the client renders it, last writer wins against its own mute state.
package enum MicLedState: UInt8, Hashable {
    case off = 0
    case on = 1
    case pulse = 2
}

package struct MicLedCommand: Equatable {
    package let controllerIndex: UInt8
    package let state: MicLedState

    package init(controllerIndex: UInt8, state: MicLedState) {
        self.controllerIndex = controllerIndex
        self.state = state
    }

    /// Parse `ctrlIdx(1) + state(1)`; nil on truncation or a state byte this
    /// client does not know, which a newer server may send.
    package static func parse(_ payload: Data) -> MicLedCommand? {
        let bytes = [UInt8](payload)
        guard bytes.count >= ProtocolConstants.micLedPayloadBytes, let state = MicLedState(rawValue: bytes[1]) else { return nil }
        return MicLedCommand(controllerIndex: bytes[0], state: state)
    }
}

/// The DualSense mic-mute button is the one free XINPUT bit of the report's
/// button word. Mute is the client's to enforce: muted means zero MIC_AUDIO
/// packets on the wire, and the bit set so host software can see the state.
package enum MicMute {
    package static let buttonBit: UInt16 = 0x0800

    package static func buttons(_ buttons: UInt16, muted: Bool) -> UInt16 {
        muted ? buttons | buttonBit : buttons & ~buttonBit
    }

    /// A muted client delivers no capture at all, silent frames included.
    package static func mayStream(muted: Bool, capAdvertised: Bool) -> Bool {
        !muted && capAdvertised
    }
}
