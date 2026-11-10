// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The Moonlight control-stream contract as Wolf's MIT source and docs give it
// (control.hpp, control-specs.adoc, input-data.adoc), the same facts the
// other three clients pin. Every value here is read by an encoder or a
// decoder in this directory and pinned by a vector in its tests.

import Foundation

package enum MoonlightProtocol {
    package static let httpPort: UInt16 = 47989
    package static let httpsPort: UInt16 = 47984
    /// The RTSP port when the launch reply's `sessionUrl0` names none.
    package static let defaultRtspPort: UInt16 = 48010
    package static let bonjourType = "_nvstream._tcp"
    /// A Moonlight session carries four pads and no more.
    package static let maxPads = 4

    // MARK: - Control packet types, u16 little-endian

    package static let packetEncrypted: UInt16 = 0x0001
    /// Wolf's control.hpp says 0x0109. The GFE-era docs say 0x0100, and the
    /// decoder reads that one as a termination too.
    package static let packetTermination: UInt16 = 0x0109
    package static let packetTerminationLegacy: UInt16 = 0x0100
    package static let packetPeriodicPing: UInt16 = 0x0200
    package static let packetInputData: UInt16 = 0x0206
    package static let eventRumbleData: UInt16 = 0x010B
    package static let eventRumbleTriggers: UInt16 = 0x5500
    package static let eventMotion: UInt16 = 0x5501
    package static let eventRgbLed: UInt16 = 0x5502
    /// The one big-endian field of the family: the reason a session ends.
    package static let terminateReasonGraceful: UInt32 = 0x8003_0023

    // MARK: - Message lengths, control header included

    package static let controlHeaderLength = 4
    package static let controllerMultiLength = 38
    /// Eight body bytes, not the seven its fields add up to: the host reads
    /// a naturally aligned struct, so the u32 sits at offset 4.
    package static let controllerArrivalLength = 20
    package static let controllerTouchLength = 32
    package static let controllerMotionLength = 28
    package static let controllerBatteryLength = 16
    package static let mouseMoveRelLength = 16
    package static let mouseButtonLength = 13
    package static let mouseScrollLength = 18
    /// The form a real client sends, captured by Wolf: an eight-byte body.
    package static let periodicPingLength = 12
    package static let terminationLength = 8

    /// The CONTROLLER_MULTI struct's fixed words, in order of appearance.
    package static let multiHeaderWord: UInt16 = 0x001A
    package static let multiMidWord: UInt16 = 0x0014
    package static let multiTailWordA: UInt16 = 0x009C
    package static let multiTailWordB: UInt16 = 0x0055
}

/// The input type word inside INPUT_DATA, u32 little-endian.
package enum MoonlightInputType {
    package static let mouseMoveRel: UInt32 = 0x0000_0007
    package static let mouseButtonDown: UInt32 = 0x0000_0008
    package static let mouseButtonUp: UInt32 = 0x0000_0009
    package static let mouseScroll: UInt32 = 0x0000_000A
    package static let controllerMulti: UInt32 = 0x0000_000C
    package static let controllerArrival: UInt32 = 0x5500_0004
    package static let controllerTouch: UInt32 = 0x5500_0005
    package static let controllerMotion: UInt32 = 0x5500_0006
    package static let controllerBattery: UInt32 = 0x5500_0007
}

/// The 32-bit button field: XUSB's low sixteen, then the extended buttons
/// the second word carries.
package enum MoonlightButton {
    package static let dpadUp: UInt32 = 0x0001
    package static let dpadDown: UInt32 = 0x0002
    package static let dpadLeft: UInt32 = 0x0004
    package static let dpadRight: UInt32 = 0x0008
    package static let start: UInt32 = 0x0010
    package static let back: UInt32 = 0x0020
    package static let leftStick: UInt32 = 0x0040
    package static let rightStick: UInt32 = 0x0080
    package static let leftButton: UInt32 = 0x0100
    package static let rightButton: UInt32 = 0x0200
    package static let home: UInt32 = 0x0400
    /// XUSB's one unassigned bit, which the satellite protocol uses for the
    /// DualSense's mic mute; no Moonlight button lives there.
    package static let reservedMicMute: UInt32 = 0x0800
    package static let buttonA: UInt32 = 0x1000
    package static let buttonB: UInt32 = 0x2000
    package static let buttonX: UInt32 = 0x4000
    package static let buttonY: UInt32 = 0x8000
    package static let paddle1: UInt32 = 0x010000
    package static let paddle2: UInt32 = 0x020000
    package static let paddle3: UInt32 = 0x040000
    package static let paddle4: UInt32 = 0x080000
    package static let touchpad: UInt32 = 0x100000
    package static let misc: UInt32 = 0x200000
}

/// The capability byte of CONTROLLER_ARRIVAL.
package enum MoonlightCapability {
    package static let analogTriggers: UInt8 = 0x01
    package static let rumble: UInt8 = 0x02
    package static let triggerRumble: UInt8 = 0x04
    package static let touchpad: UInt8 = 0x08
    package static let accelerometer: UInt8 = 0x10
    package static let gyro: UInt8 = 0x20
    package static let battery: UInt8 = 0x40
    package static let rgbLed: UInt8 = 0x80
}

package enum MoonlightControllerType {
    package static let unknown: UInt8 = 0x00
    package static let xbox: UInt8 = 0x01
    package static let playStation: UInt8 = 0x02
    package static let nintendo: UInt8 = 0x03
    /// A client-side pick that never reaches the wire: resolved to one of
    /// the three before the arrival is sent.
    package static let auto: UInt8 = 0xFF
}

package enum MoonlightBatteryState {
    package static let unknown: UInt8 = 0x00
    package static let notPresent: UInt8 = 0x01
    package static let discharging: UInt8 = 0x02
    package static let charging: UInt8 = 0x03
    package static let notCharging: UInt8 = 0x04
    package static let full: UInt8 = 0x05
    package static let percentageUnknown: UInt8 = 0xFF
}

package enum MoonlightTouchEvent {
    package static let down: UInt8 = 0x01
    package static let up: UInt8 = 0x02
    package static let move: UInt8 = 0x03
}

package enum MoonlightMotionType {
    package static let accelerometer: UInt8 = 0x01
    package static let gyro: UInt8 = 0x02
}

package enum MoonlightMouseButton {
    package static let left: UInt8 = 0x01
    package static let middle: UInt8 = 0x02
    package static let right: UInt8 = 0x03
}
