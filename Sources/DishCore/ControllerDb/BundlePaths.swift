// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// Every controller path in the support file, input and output (dish-website
// `docs/diagnostics-bundle.md`, "Every controller path, input and output"):
// what went in and what came out, as counts and the last value, never a
// stream. A field a path cannot know is null, not invented.

import Foundation

/// The last state a pad published, as the wire carries it.
package struct BundleInputState: Equatable, Encodable {
    package let buttons: UInt16
    package let lx: Int16
    package let ly: Int16
    package let rx: Int16
    package let ry: Int16
    package let lt: UInt8
    package let rt: UInt8
    package let ext: UInt32

    package init(buttons: UInt16, lx: Int16, ly: Int16, rx: Int16, ry: Int16, lt: UInt8, rt: UInt8, ext: UInt32) {
        self.buttons = buttons
        self.lx = lx
        self.ly = ly
        self.rx = rx
        self.ry = ry
        self.lt = lt
        self.rt = rt
        self.ext = ext
    }

    package init(_ report: GamepadReport) {
        self.init(
            buttons: report.buttons,
            lx: report.lx,
            ly: report.ly,
            rx: report.rx,
            ry: report.ry,
            lt: report.lt,
            rt: report.rt,
            ext: report.extButtons
        )
    }

    private enum CodingKeys: String, CodingKey {
        case buttons, lx, ly, rx, ry, lt, rt, ext
    }

    /// The button words in hex, as the wire's bits read: four digits for
    /// the XUSB word, eight for the extended one.
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(format: "%04x", buttons), forKey: .buttons)
        try container.encode(lx, forKey: .lx)
        try container.encode(ly, forKey: .ly)
        try container.encode(rx, forKey: .rx)
        try container.encode(ry, forKey: .ry)
        try container.encode(lt, forKey: .lt)
        try container.encode(rt, forKey: .rt)
        try container.encode(String(format: "%08x", ext), forKey: .ext)
    }
}

/// What went in: the frames published, their rate, and the last one.
package struct BundleInput: Equatable, Encodable {
    package let frames: UInt64
    /// Nil while the rate has not been sampled twice.
    package let rateHz: Int?
    package let last: BundleInputState?

    package init(frames: UInt64, rateHz: Int?, last: BundleInputState?) {
        self.frames = frames
        self.rateHz = rateHz
        self.last = last
    }

    private enum CodingKeys: String, CodingKey {
        case frames, rateHz, last
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frames, forKey: .frames)
        try container.encode(rateHz, forKey: .rateHz)
        try container.encode(last, forKey: .last)
    }
}

/// Who acts on a pad's rumble: the app's own write to the pad over USB or
/// over Bluetooth LE, the phone's own haptics, the platform's framework,
/// or nothing at all.
package enum BundleRumbleTarget: String, Equatable {
    case directUsb
    case directBle
    case phone
    case framework
    case none
}

package struct BundleRumble: Equatable, Encodable {
    package let strong: UInt16
    package let weak: UInt16
    package let atMs: Int64

    package init(strong: UInt16, weak: UInt16, atMs: Int64) {
        self.strong = strong
        self.weak = weak
        self.atMs = atMs
    }
}

package struct BundleColour: Equatable, Encodable {
    package let r: UInt8
    package let g: UInt8
    package let b: UInt8
    package let atMs: Int64

    package init(r: UInt8, g: UInt8, b: UInt8, atMs: Int64) {
        self.r = r
        self.g = g
        self.b = b
        self.atMs = atMs
    }
}

/// The player LEDs as the pad was told: the framework takes a player
/// number, not the host's mask.
package struct BundlePlayer: Equatable, Encodable {
    package let player: Int
    package let atMs: Int64

    package init(player: Int, atMs: Int64) {
        self.player = player
        self.atMs = atMs
    }
}

/// One output lane: how many commands reached the pad's actuator, and the
/// last of them where the lane keeps one.
package struct BundleLane<Last: Equatable & Sendable & Encodable>: Equatable, Encodable {
    package let count: UInt64
    package let last: Last?

    package init(count: UInt64, last: Last?) {
        self.count = count
        self.last = last
    }

    private enum CodingKeys: String, CodingKey {
        case count, last
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(count, forKey: .count)
        try container.encode(last, forKey: .last)
    }
}

/// A lane whose commands carry nothing a reader needs beyond their count.
package struct BundleCount: Equatable, Encodable {
    package let count: UInt64

    package init(count: UInt64) {
        self.count = count
    }
}

/// The last write the app made to a pad itself, in the shape the other
/// clients' `lastWrite` has, plus the bytes as hex. Only the Steam pads'
/// GATT writes have one: a GameController pad is written by the framework,
/// and the app never sees the bytes.
package struct BundleWrite: Equatable, Encodable {
    /// `gattWrite`: a characteristic write with response.
    package let route: String
    /// The report's id as two hex digits.
    package let reportId: String
    /// The value as the app handed it to the radio (the report past its id), lower-case hex.
    package let bytes: String
    /// Nil until the radio's write callback has answered.
    package let ok: Bool?
    /// The callback's error as `domain:code`; nil on success and while pending.
    package let err: String?
    package let atMs: Int64

    package init(reportId: UInt8, bytes: [UInt8], ok: Bool?, err: String?, atMs: Int64) {
        route = "gattWrite"
        self.reportId = hexEncodeLower([reportId])
        self.bytes = hexEncodeLower(bytes)
        self.ok = ok
        self.err = err
        self.atMs = atMs
    }

    private enum CodingKeys: String, CodingKey {
        case route, reportId, bytes, ok, err, atMs
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(route, forKey: .route)
        try container.encode(reportId, forKey: .reportId)
        try container.encode(bytes, forKey: .bytes)
        try container.encode(ok, forKey: .ok)
        try container.encode(err, forKey: .err)
        try container.encode(atMs, forKey: .atMs)
    }
}

/// What came out, per lane. iOS carries no trigger rumble, mic LED,
/// speaker or haptics audio lane, so those are null.
package struct BundleOutput: Equatable, Encodable {
    package let rumble: BundleLane<BundleRumble>
    package let rumbleTarget: BundleRumbleTarget
    /// Nil for a path whose writes the app never sees.
    package let rumbleWrite: BundleWrite?
    package let lightbar: BundleLane<BundleColour>
    package let playerLeds: BundleLane<BundlePlayer>
    package let triggerEffects: BundleCount

    package init(
        rumble: BundleLane<BundleRumble>,
        rumbleTarget: BundleRumbleTarget,
        rumbleWrite: BundleWrite? = nil,
        lightbar: BundleLane<BundleColour>,
        playerLeds: BundleLane<BundlePlayer>,
        triggerEffects: BundleCount
    ) {
        self.rumble = rumble
        self.rumbleTarget = rumbleTarget
        self.rumbleWrite = rumbleWrite
        self.lightbar = lightbar
        self.playerLeds = playerLeds
        self.triggerEffects = triggerEffects
    }

    private enum CodingKeys: String, CodingKey {
        case rumble, triggerRumble, lightbar, playerLeds, triggerEffects, micLed, speaker, haptics
    }

    private enum RumbleKeys: String, CodingKey {
        case count, target, last, lastWrite
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var lane = container.nestedContainer(keyedBy: RumbleKeys.self, forKey: .rumble)
        try lane.encode(rumble.count, forKey: .count)
        try lane.encode(rumbleTarget.rawValue, forKey: .target)
        try lane.encode(rumble.last, forKey: .last)
        try lane.encode(rumbleWrite, forKey: .lastWrite)
        try container.encodeNil(forKey: .triggerRumble)
        try container.encode(lightbar, forKey: .lightbar)
        try container.encode(playerLeds, forKey: .playerLeds)
        try container.encode(triggerEffects, forKey: .triggerEffects)
        try container.encodeNil(forKey: .micLed)
        try container.encodeNil(forKey: .speaker)
        try container.encodeNil(forKey: .haptics)
    }
}

/// How a pad Dish reads over Bluetooth itself is attached; never an address.
package struct BundleBluetooth: Equatable, Encodable {
    package let profile: String
    package let transportLayer: String

    package init(profile: String, transportLayer: String) {
        self.profile = profile
        self.transportLayer = transportLayer
    }

    /// Dish's own client of a pad's GATT service.
    package static let lowEnergy = BundleBluetooth(profile: "ble", transportLayer: "le")
}

// MARK: - The device

package enum BundleThermal: String, Equatable {
    case nominal
    case fair
    case serious
    case critical
}

package struct BundleBattery: Equatable, Encodable {
    /// Nil while the device reports a state but no level.
    package let level: Int?
    package let charging: Bool

    package init(level: Int?, charging: Bool) {
        self.level = level
        self.charging = charging
    }

    private enum CodingKeys: String, CodingKey {
        case level, charging
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(level, forKey: .level)
        try container.encode(charging, forKey: .charging)
    }
}

/// What the device says of itself that explains a latency or feedback
/// complaint: its battery, its temperature and its power saving. iOS gives
/// an app no Wi-Fi signal and no word on a USB host, so both are null.
package struct BundleConditions: Equatable {
    package let battery: BundleBattery?
    package let thermal: BundleThermal?
    package let powerSave: Bool?

    package init(battery: BundleBattery?, thermal: BundleThermal?, powerSave: Bool?) {
        self.battery = battery
        self.thermal = thermal
        self.powerSave = powerSave
    }

    package static let unknown = BundleConditions(battery: nil, thermal: nil, powerSave: nil)
}

// MARK: - The report

/// What the person says the problem is about, in the contract's words.
package enum ReportCategory: String, CaseIterable, Equatable {
    case notRecognised
    case noFeedback
    case connection
    case audio
    case other
    case question
}

/// The person's own words, first in the mail and in the file.
package struct BundleReport: Equatable, Encodable {
    package let category: ReportCategory
    package let text: String
    /// The record id, or the pad's product name, or nil for none picked.
    package let controller: String?

    package init(category: ReportCategory, text: String, controller: String?) {
        self.category = category
        self.text = text
        self.controller = controller
    }

    private enum CodingKeys: String, CodingKey {
        case category, text, controller
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(category.rawValue, forKey: .category)
        try container.encode(text, forKey: .text)
        try container.encode(controller, forKey: .controller)
    }
}

/// `Dish support: <category> · <app> <version> on <model>`, the contract's
/// subject; the category is the person's own language's word for it.
package func supportMailSubject(category: String, app: String, version: String, model: String) -> String {
    "Dish support: \(category) · \(app) \(version) on \(model)"
}

/// Who acts on a pad's rumble on this path: the on-screen controller's is
/// the phone's own haptics, a pad GameController reads is driven through
/// the framework when it has motors, and a pad Dish reads over Bluetooth
/// is written by Dish itself.
package func rumbleTarget(path: BundlePath, hasRumble: Bool) -> BundleRumbleTarget {
    switch path {
    case .virtual: .phone
    case .gameController: hasRumble ? .framework : .none
    case .bluetooth: .directBle
    }
}

/// The device's battery as the file tells it: on power while it charges or
/// sits full on the cable; nil while the device reports nothing.
package func bundleBattery(_ reading: BatteryReading?) -> BundleBattery? {
    guard let reading else { return nil }
    let onPower = reading.state == .charging || reading.state == .full
    return BundleBattery(level: reading.level, charging: onPower)
}
