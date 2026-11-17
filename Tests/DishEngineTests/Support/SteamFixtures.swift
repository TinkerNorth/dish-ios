// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The Steam Controllers' byte builders, copied from DishCoreTests'
// `SteamFixtures.swift` (dish-mac's `DirectInputFixtures.swift`), for the
// links' tests to feed the radio what a pad sends.

import Foundation

/// A 2015 Steam Controller state packet over Bluetooth LE under construction,
/// from SDL's `UpdateBLESteamControllerState`: the type (4, a state) in the
/// first byte's low nibble, the option mask's low byte in its high nibble and
/// the mask's next byte after it, then each chunk the mask names, in the
/// mask's bit order. `reports` cuts it into input reports as SDL's iOS
/// backend hands them on: report 3, the segment's header (0x80 data, 0x40
/// its packet's last, its number), 18 bytes. `values` are the same segments
/// as CoreBluetooth delivers them, without the report id.
struct SteamBlePacketBytes {
    static let buttons: UInt32 = 0x0010
    static let triggers: UInt32 = 0x0020
    static let highButtons: UInt32 = 0x0040
    static let stick: UInt32 = 0x0080
    static let leftPad: UInt32 = 0x0100
    static let rightPad: UInt32 = 0x0200
    static let accel: UInt32 = 0x0400
    static let gyro: UInt32 = 0x0800
    static let quaternion: UInt32 = 0x1000
    static let payloadLength = 18

    var type: UInt8 = 4
    private var chunks: [UInt32: [UInt8]] = [:]

    func with(_ chunk: UInt32, _ bytes: [UInt8]) -> SteamBlePacketBytes {
        var packet = self
        packet.chunks[chunk] = bytes
        return packet
    }

    /// The low three bytes of the button word.
    func buttons(_ word: UInt32) -> SteamBlePacketBytes {
        with(Self.buttons, [UInt8(word & 0xFF), UInt8((word >> 8) & 0xFF), UInt8((word >> 16) & 0xFF)])
    }

    func triggers(left: UInt8, right: UInt8) -> SteamBlePacketBytes {
        with(Self.triggers, [left, right])
    }

    func stick(x: Int16, y: Int16) -> SteamBlePacketBytes {
        with(Self.stick, le16(x) + le16(y))
    }

    func leftPad(x: Int16, y: Int16) -> SteamBlePacketBytes {
        with(Self.leftPad, le16(x) + le16(y))
    }

    func rightPad(x: Int16, y: Int16) -> SteamBlePacketBytes {
        with(Self.rightPad, le16(x) + le16(y))
    }

    func accel(_ x: Int16, _ y: Int16, _ z: Int16) -> SteamBlePacketBytes {
        with(Self.accel, le16(x) + le16(y) + le16(z))
    }

    func gyro(_ x: Int16, _ y: Int16, _ z: Int16) -> SteamBlePacketBytes {
        with(Self.gyro, le16(x) + le16(y) + le16(z))
    }

    var packet: [UInt8] {
        let mask = chunks.keys.reduce(0, |)
        let body = chunks.keys.sorted().flatMap { chunks[$0] ?? [] }
        return [UInt8(mask & 0xF0) | type, UInt8(mask >> 8)] + body
    }

    /// The packet as consecutive segments, the last flagged.
    var reports: [[UInt8]] {
        let bytes = packet
        let count = (bytes.count + Self.payloadLength - 1) / Self.payloadLength
        return (0 ..< count).map { Self.segment(number: $0, last: $0 == count - 1, payloadOf(bytes, segment: $0)) }
    }

    /// The segments as the input characteristic's values.
    var values: [[UInt8]] {
        reports.map { Array($0.dropFirst()) }
    }

    /// One input report: report 3, the header, the payload padded to 18 bytes.
    static func segment(number: Int, last: Bool, _ payload: [UInt8], carriesData: Bool = true) -> [UInt8] {
        let data: UInt8 = carriesData ? 0x80 : 0
        let lastFlag: UInt8 = last ? 0x40 : 0
        let header = data | lastFlag | UInt8(number)
        return [0x03, header] + payload + [UInt8](repeating: 0, count: payloadLength - payload.count)
    }
}

func le16(_ value: Int16) -> [UInt8] {
    let word = UInt16(bitPattern: value)
    return [UInt8(word & 0xFF), UInt8(word >> 8)]
}

private func payloadOf(_ packet: [UInt8], segment: Int) -> [UInt8] {
    Array(packet.dropFirst(segment * SteamBlePacketBytes.payloadLength).prefix(SteamBlePacketBytes.payloadLength))
}

/// A 2026 Steam Controller state report under construction: the report id,
/// then SDL's `TritonMTUNoQuat_t` (46 bytes in all). `value` is the report
/// as CoreBluetooth delivers it, without the id.
struct TritonReportBytes {
    var bytes: [UInt8]

    /// A state report with the 32-bit button word at bytes 2...5 and the
    /// IMU tick where the report's shape keeps it.
    static func state(_ buttons: UInt32 = 0, reportId: UInt8 = 0x42, length: Int = 46, imuTick: UInt32 = 0) -> TritonReportBytes {
        var report = TritonReportBytes(bytes: [UInt8](repeating: 0, count: length))
        report.bytes[0] = reportId
        report.bytes[2] = UInt8(buttons & 0xFF)
        report.bytes[3] = UInt8((buttons >> 8) & 0xFF)
        report.bytes[4] = UInt8((buttons >> 16) & 0xFF)
        report.bytes[5] = UInt8((buttons >> 24) & 0xFF)
        report.setImuTick(imuTick)
        return report
    }

    var value: [UInt8] {
        Array(bytes.dropFirst())
    }

    /// Four bytes at 30 (`TritonMTUIMUNoQuat_t`), or two at 32 on the
    /// timestamped report 0x47 (`TritonMTUIMUNoQuat32usTS_t`).
    mutating func setImuTick(_ tick: UInt32) {
        if bytes[0] == 0x47 {
            setLe16(32, Int16(truncatingIfNeeded: tick))
        } else {
            setLe32(30, tick)
        }
    }

    mutating func setLe16(_ offset: Int, _ value: Int16) {
        let word = UInt16(bitPattern: value)
        bytes[offset] = UInt8(word & 0xFF)
        bytes[offset + 1] = UInt8(word >> 8)
    }

    mutating func setLe32(_ offset: Int, _ value: UInt32) {
        bytes[offset] = UInt8(value & 0xFF)
        bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
        bytes[offset + 2] = UInt8((value >> 16) & 0xFF)
        bytes[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
