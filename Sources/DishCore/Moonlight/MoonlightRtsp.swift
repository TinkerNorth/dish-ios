// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The plaintext RTSP of the stream handshake (Wolf rtsp.adoc, parser.hpp),
// in the dialect real clients speak and hosts parse with a strict grammar:
// `<CMD> <target> RTSP/1.0`, CSeq, the client version, the session once the
// first SETUP named one, then the request's own options, a blank line, and
// the payload. Pure text; the engine writes it and reads the reply, one TCP
// connection per message because a host hangs up after each answer.

import Foundation

package struct MoonlightStreamConfig: Equatable {
    package var width = 1280
    package var height = 720
    package var fps = 30
    package var bitrateKbps = 500
    package var packetSize = 1024
    package var audioChannels = 2

    package init() {}
}

package struct MoonlightRtspRequest: Equatable {
    package var command: String
    package var target: String
    package var cseq: Int
    package var sessionId: String
    package var options: [(String, String)]
    package var payload: String

    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.encode() == rhs.encode()
    }

    /// The wire text, CRLF throughout.
    package func encode() -> String {
        var out = "\(command) \(target) RTSP/1.0\r\n"
        out += "CSeq: \(cseq)\r\n"
        out += "X-GS-ClientVersion: \(MoonlightRtsp.clientVersion)\r\n"
        if !sessionId.isEmpty { out += "Session: \(sessionId)\r\n" }
        for (name, value) in options {
            out += "\(name): \(value)\r\n"
        }
        return out + "\r\n" + payload
    }
}

package enum MoonlightRtsp {
    /// What Moonlight 5.x clients advertise.
    package static let clientVersion = "14"
    package static let announceTarget = "streamid=control/13/0"

    package static func options(cseq: Int, target: String) -> MoonlightRtspRequest {
        MoonlightRtspRequest(command: "OPTIONS", target: target, cseq: cseq, sessionId: "", options: [], payload: "")
    }

    package static func describe(cseq: Int, target: String) -> MoonlightRtspRequest {
        MoonlightRtspRequest(
            command: "DESCRIBE",
            target: target,
            cseq: cseq,
            sessionId: "",
            options: [("Accept", "application/sdp")],
            payload: ""
        )
    }

    /// `streamId` is audio, video or control. The host assigns the real
    /// ports; the client-port hint rides along as it does for real clients.
    package static func setup(cseq: Int, streamId: String, sessionId: String) -> MoonlightRtspRequest {
        MoonlightRtspRequest(
            command: "SETUP",
            target: "streamid=\(streamId)/0/0",
            cseq: cseq,
            sessionId: sessionId,
            options: [
                ("Transport", "unicast;X-GS-ClientPort=50000-50001"),
                ("If-Modified-Since", "Thu, 01 Jan 1970 00:00:00 GMT")
            ],
            payload: ""
        )
    }

    package static func announce(cseq: Int, sessionId: String, sdp: String) -> MoonlightRtspRequest {
        MoonlightRtspRequest(
            command: "ANNOUNCE",
            target: announceTarget,
            cseq: cseq,
            sessionId: sessionId,
            options: [("Content-type", "application/sdp"), ("Content-length", String(sdp.utf8.count))],
            payload: sdp
        )
    }

    package static func play(cseq: Int, target: String, sessionId: String) -> MoonlightRtspRequest {
        MoonlightRtspRequest(command: "PLAY", target: target, cseq: cseq, sessionId: sessionId, options: [], payload: "")
    }

    /// The whole attribute set a real client sends, one per line. A host
    /// builds its stream configuration by looking each up by name and a miss
    /// is fatal: against a live Sunshine host the handful the dish itself
    /// cares about is answered 400, this set 200. Nothing here is decoration.
    package static func announceSdp(_ config: MoonlightStreamConfig) -> String {
        let lines: [String] = [
            "v=0",
            "o=android 0 14 IN IPv4 0.0.0.0",
            "s=NVIDIA Streaming Client",
            "a=x-nv-video[0].clientViewportWd:\(config.width)",
            "a=x-nv-video[0].clientViewportHt:\(config.height)",
            "a=x-nv-video[0].maxFPS:\(config.fps)",
            "a=x-nv-video[0].packetSize:\(config.packetSize)",
            "a=x-nv-video[0].rateControlMode:4",
            "a=x-nv-video[0].timeoutLengthMs:7000",
            "a=x-nv-video[0].framesWithInvalidRefThreshold:0",
            "a=x-nv-video[0].refPicInvalidation:0",
            "a=x-nv-video[0].encoderCscMode:0",
            "a=x-nv-video[0].dynamicRangeMode:0",
            "a=x-nv-video[0].maxNumReferenceFrames:1",
            "a=x-nv-video[0].videoEncoderSlicesPerFrame:1",
            "a=x-nv-video[0].clientRefreshRateX100:\(config.fps * 100)",
            "a=x-nv-vqos[0].bitStreamFormat:0",
            "a=x-nv-vqos[0].bw.minimumBitrateKbps:\(config.bitrateKbps)",
            "a=x-nv-vqos[0].bw.maximumBitrateKbps:\(config.bitrateKbps)",
            "a=x-nv-vqos[0].fec.enable:1",
            "a=x-nv-vqos[0].fec.minRequiredFecPackets:2",
            "a=x-nv-vqos[0].fec.repairPercent:20",
            "a=x-nv-vqos[0].drc.enable:0",
            "a=x-nv-vqos[0].videoQualityScoreUpdateTime:5000",
            "a=x-nv-vqos[0].qosTrafficType:5",
            "a=x-nv-aqos.qosTrafficType:4",
            "a=x-nv-aqos.packetDuration:5",
            "a=x-nv-audio.surround.numChannels:\(config.audioChannels)",
            "a=x-nv-audio.surround.channelMask:3",
            "a=x-nv-audio.surround.enable:0",
            "a=x-nv-audio.surround.AudioQuality:0",
            "a=x-nv-general.useReliableUdp:13",
            "a=x-nv-general.featureFlags:167",
            "a=x-ml-general.featureFlags:3",
            "a=x-ss-general.encryptionEnabled:0",
            "t=0 0"
        ]
        return lines.map { $0 + "\r\n" }.joined()
    }
}

/// A host's answer: the status line, the options in the order written, the
/// payload after the blank line. Hosts emit CRLF or bare LF; both parse.
package struct MoonlightRtspResponse: Equatable {
    package var statusCode: Int
    package var statusMessage: String
    package var cseq: Int
    package var options: [String: String]
    package var payload: String

    package var ok: Bool {
        statusCode == 200
    }

    /// Nil when the first line is not an `RTSP/` status line, so a truncated
    /// or foreign reply is rejected rather than half-read.
    package static func parse(_ text: String) -> MoonlightRtspResponse? {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let split = normalized.range(of: "\n\n")
        let head = split.map { String(normalized[..<$0.lowerBound]) } ?? normalized
        let payload = split.map { String(normalized[$0.upperBound...]) } ?? ""
        var lines = head.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !lines.isEmpty, let status = statusLine(lines.removeFirst()) else { return nil }
        var cseq = 0
        var options: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if name.caseInsensitiveCompare("CSeq") == .orderedSame {
                cseq = Int(value) ?? cseq
            } else {
                options[name] = value
            }
        }
        return MoonlightRtspResponse(statusCode: status.code, statusMessage: status.message, cseq: cseq, options: options, payload: payload)
    }

    package func option(_ name: String) -> String? {
        options.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    /// `server_port=<n>` of the Transport option: the port the stream answers on.
    package func serverPort() -> UInt16? {
        guard let transport = option("Transport"), let range = transport.range(of: "server_port=") else { return nil }
        let digits = transport[range.upperBound...].prefix { $0.isNumber }
        guard let port = Int(digits), (1 ... 65535).contains(port) else { return nil }
        return UInt16(port)
    }

    /// The ENet connect token of the control SETUP, unsigned 32-bit: a live
    /// host's routinely sits above Int32.max (4270471497 came off a Sunshine),
    /// so it is read wide and narrowed, never parsed as a signed number.
    package func connectData() -> UInt32? {
        guard let text = option("X-SS-Connect-Data")?.trimmingCharacters(in: .whitespaces), !text.isEmpty,
              text.allSatisfy(\.isNumber), let wide = UInt64(text) else { return nil }
        return UInt32(truncatingIfNeeded: wide)
    }

    package func contentLength() -> Int? {
        option("Content-length").flatMap(Int.init).flatMap { $0 >= 0 ? $0 : nil }
    }

    /// The media ping payload, minted per session: unless it reaches the
    /// ports the SETUPs named, the host logs an initial ping timeout and ends
    /// the session seconds after PLAY.
    package func pingPayload() -> String? {
        option("X-SS-Ping-Payload").flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The session the host assigned, without any `;timeout=` that follows it.
    package func sessionId() -> String? {
        guard let value = option("Session") else { return nil }
        let id = value.split(separator: ";", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return id.isEmpty ? nil : id
    }

    private static func statusLine(_ line: String) -> (code: Int, message: String)? {
        let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2, parts[0].hasPrefix("RTSP/"), let code = Int(parts[1]) else { return nil }
        return (code, parts.count > 2 ? String(parts[2]) : "")
    }
}
