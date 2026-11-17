// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The 2015 Steam Controller's button word, axes and IMU as SDL's
// `SDL_hidapi_steam.c` maps them, and the feature-report messages that quiet
// its keyboard and mouse emulation ("lizard mode") and give them back. Ported
// from dish-mac's `SteamController.swift` for the pad's Bluetooth LE decoder
// (`SteamControllerBle.swift`), without the wired packet decoder: iOS gives an
// app no USB or HID access to the pad on its cable or its receiver
// (Tests/PARITY.md). Decoding reads the caller's buffer in place and builds
// no collection.

import Foundation

/// One state off a Steam Controller of either generation: the pad on the
/// XUSB layout, its IMU when the report carries a new sample, and its two
/// trackpads raw, for the router to land by the slot's pick.
package enum SteamReading: Equatable {
    case state(GamepadReport, motion: MotionSample?, pads: SteamPads)
}

enum SteamScale {
    /// Valve's trigger full scale, so the throw saturates before the raw rail.
    static let triggerFullScale: Int32 = 26000
    static let triggerWidenShift: Int32 = 7
    static let triggerMax: Int32 = 255
    /// 15 degrees in Q16: the pads sit rotated on the shell, as SDL corrects.
    static let padCos: Int64 = 63303
    static let padSin: Int64 = 16962
    static let q16: Int64 = 65536
    /// Gyro over ±2000 deg/s and accel over ±2 g on ±32768, against the
    /// wire's ±2000 deg/s and ±4 g on ±32767.
    static let gyroDivisor: Int64 = 32768
    static let accelDivisor: Int64 = 65536
    static let wireMax: Int64 = 32767
}

enum SteamButtonMask {
    static let rightTriggerClick: UInt32 = 0x000001
    static let leftTriggerClick: UInt32 = 0x000002
    static let rightBumper: UInt32 = 0x000004
    static let leftBumper: UInt32 = 0x000008
    static let north: UInt32 = 0x000010
    static let east: UInt32 = 0x000020
    static let west: UInt32 = 0x000040
    static let south: UInt32 = 0x000080
    static let dpadUp: UInt32 = 0x000100
    static let dpadRight: UInt32 = 0x000200
    static let dpadLeft: UInt32 = 0x000400
    static let dpadDown: UInt32 = 0x000800
    static let menu: UInt32 = 0x001000
    static let guide: UInt32 = 0x002000
    static let escape: UInt32 = 0x004000
    static let backLeft: UInt32 = 0x008000
    static let backRight: UInt32 = 0x010000
    static let leftPadClicked: UInt32 = 0x020000
    static let rightPadClicked: UInt32 = 0x040000
    static let leftPadFinger: UInt32 = 0x080000
    static let rightPadFinger: UInt32 = 0x100000
    static let stickButton: UInt32 = 0x400000
}

/// One bit of a Steam button word and the wire button it presses.
struct SteamButtonBit {
    let mask: UInt32
    let button: WireButton
}

/// By position, as for every pad: south is XUSB A. Menu is Back and Escape
/// is Start, as SDL has them; the stick's click is its own bit, and the pad
/// clicks are the trackpad router's.
let steamControllerButtonBits = [
    SteamButtonBit(mask: SteamButtonMask.south, button: .faceA),
    SteamButtonBit(mask: SteamButtonMask.east, button: .faceB),
    SteamButtonBit(mask: SteamButtonMask.west, button: .faceX),
    SteamButtonBit(mask: SteamButtonMask.north, button: .faceY),
    SteamButtonBit(mask: SteamButtonMask.leftBumper, button: .leftShoulder),
    SteamButtonBit(mask: SteamButtonMask.rightBumper, button: .rightShoulder),
    SteamButtonBit(mask: SteamButtonMask.menu, button: .back),
    SteamButtonBit(mask: SteamButtonMask.escape, button: .start),
    SteamButtonBit(mask: SteamButtonMask.guide, button: .guide),
    SteamButtonBit(mask: SteamButtonMask.dpadUp, button: .dpadUp),
    SteamButtonBit(mask: SteamButtonMask.dpadDown, button: .dpadDown),
    SteamButtonBit(mask: SteamButtonMask.dpadLeft, button: .dpadLeft),
    SteamButtonBit(mask: SteamButtonMask.dpadRight, button: .dpadRight),
    SteamButtonBit(mask: SteamButtonMask.stickButton, button: .leftThumb)
]

func steamButtons(_ held: UInt32, _ table: [SteamButtonBit]) -> WireButtonWord {
    var word = WireButtonWord()
    for bit in table where held & bit.mask != 0 {
        word.insert(bit.button)
    }
    return word
}

/// One bit of a Steam button word and the extended button it is, in SDL's
/// names (`ProtocolConstants.extButton*`).
struct SteamExtendedBit {
    let mask: UInt32
    let ext: UInt32
}

/// The grips are SDL's two Steam paddles and the full-pull trigger bits its
/// trigger clicks; the pad clicks are the trackpad router's.
let steamControllerExtendedBits = [
    SteamExtendedBit(mask: SteamButtonMask.backLeft, ext: ProtocolConstants.extButtonLeftPaddle1),
    SteamExtendedBit(mask: SteamButtonMask.backRight, ext: ProtocolConstants.extButtonRightPaddle1),
    SteamExtendedBit(mask: SteamButtonMask.leftTriggerClick, ext: ProtocolConstants.extButtonLeftTriggerClick),
    SteamExtendedBit(mask: SteamButtonMask.rightTriggerClick, ext: ProtocolConstants.extButtonRightTriggerClick)
]

func steamExtendedButtons(_ held: UInt32, _ table: [SteamExtendedBit]) -> UInt32 {
    var word: UInt32 = 0
    for bit in table where held & bit.mask != 0 {
        word |= bit.ext
    }
    return word
}

func steamLe16(_ report: UnsafeBufferPointer<UInt8>, _ offset: Int) -> Int16 {
    let low = UInt16(report[offset])
    let high = UInt16(report[offset + 1]) << 8
    return Int16(bitPattern: low | high)
}

/// Three bytes as one little-endian word: the 2015 pad's buttons.
func steamLe24(_ report: UnsafeBufferPointer<UInt8>, _ offset: Int) -> UInt32 {
    let low = UInt32(report[offset])
    let middle = UInt32(report[offset + 1]) << 8
    let high = UInt32(report[offset + 2]) << 16
    return low | middle | high
}

/// Two axes as the 2015 pad sends them: a trackpad's or the stick's.
struct SteamAxisPair: Equatable {
    static let zero = SteamAxisPair(x: 0, y: 0)

    let x: Int16
    let y: Int16
}

/// Three axes as the 2015 pad sends them: its accel's or its gyro's.
struct SteamAxisTriple: Equatable {
    static let zero = SteamAxisTriple(x: 0, y: 0, z: 0)

    let x: Int16
    let y: Int16
    let z: Int16
}

func steamAxisPair(_ report: UnsafeBufferPointer<UInt8>, at offset: Int) -> SteamAxisPair {
    SteamAxisPair(x: steamLe16(report, offset), y: steamLe16(report, offset + 2))
}

func steamAxisTriple(_ report: UnsafeBufferPointer<UInt8>, at offset: Int) -> SteamAxisTriple {
    SteamAxisTriple(x: steamLe16(report, offset), y: steamLe16(report, offset + 2), z: steamLe16(report, offset + 4))
}

func steamGyroToWire(_ raw: Int32) -> Int16 {
    Int16(clamping: Int64(raw) * SteamScale.wireMax / SteamScale.gyroDivisor)
}

func steamAccelToWire(_ raw: Int32) -> Int16 {
    Int16(clamping: Int64(raw) * SteamScale.wireMax / SteamScale.accelDivisor)
}

/// The two pads as the router takes them, each read while a finger is on
/// it; a pad's click counts only with a finger on it, as SDL reads the left.
func steamPads(left leftAxes: SteamAxisPair, right rightAxes: SteamAxisPair, held: UInt32) -> SteamPads {
    let leftFinger = held & SteamButtonMask.leftPadFinger != 0
    let rightFinger = held & SteamButtonMask.rightPadFinger != 0
    let left = steamPad(leftAxes, fingerDown: leftFinger, rotation: .leftPad)
    let right = steamPad(rightAxes, fingerDown: rightFinger, rotation: .rightPad)
    return SteamPads(
        left: SteamPadSample(active: left.active, x: left.x, y: left.y, clicked: leftFinger && held & SteamButtonMask.leftPadClicked != 0),
        right: SteamPadSample(active: right.active, x: right.x, y: right.y, clicked: held & SteamButtonMask.rightPadClicked != 0)
    )
}

/// SDL rotates the right pad by the shell angle and the left pad by its
/// negative.
private enum SteamPadRotation {
    case leftPad
    case rightPad
}

/// A pad rotated back square while a finger is on it; SDL's further +1000
/// per axis would park a stick off centre, so it is left out.
private func steamPad(_ axes: SteamAxisPair, fingerDown: Bool, rotation: SteamPadRotation) -> SteamPadSample {
    guard fingerDown else { return SteamPadSample() }
    let x = Int64(axes.x)
    let y = Int64(axes.y)
    switch rotation {
    case .rightPad:
        let rotatedX = (SteamScale.padCos * x - SteamScale.padSin * y) / SteamScale.q16
        let rotatedY = (SteamScale.padSin * x + SteamScale.padCos * y) / SteamScale.q16
        return SteamPadSample(active: true, x: Int16(clamping: rotatedX), y: Int16(clamping: rotatedY))
    case .leftPad:
        let rotatedX = (SteamScale.padCos * x + SteamScale.padSin * y) / SteamScale.q16
        let rotatedY = (SteamScale.padCos * y - SteamScale.padSin * x) / SteamScale.q16
        return SteamPadSample(active: true, x: Int16(clamping: rotatedX), y: Int16(clamping: rotatedY))
    }
}

/// The byte widened to Valve's 15-bit scale, saturating at its full scale.
func steamTrigger(_ raw: UInt8) -> UInt8 {
    let widened = Int32(raw) << SteamScale.triggerWidenShift | Int32(raw)
    let capped = min(widened, SteamScale.triggerFullScale)
    return UInt8(capped * SteamScale.triggerMax / SteamScale.triggerFullScale)
}

/// SDL's axes onto the wire: pitch on gyro X, yaw on gyro Z, roll on gyro
/// Y; accel X, Z and minus Y. An all-zero block means the IMU setting never
/// took, and publishing it would stream a dead sensor.
func steamMotion(accel: SteamAxisTriple, gyro: SteamAxisTriple) -> MotionSample? {
    let ax = Int32(accel.x)
    let ay = Int32(accel.y)
    let az = Int32(accel.z)
    let gx = Int32(gyro.x)
    let gy = Int32(gyro.y)
    let gz = Int32(gyro.z)
    let silent = (ax | ay | az | gx | gy | gz) == 0
    guard !silent else { return nil }
    return MotionSample(
        gyroX: steamGyroToWire(gx),
        gyroY: steamGyroToWire(gz),
        gyroZ: steamGyroToWire(gy),
        accelX: steamAccelToWire(ax),
        accelY: steamAccelToWire(az),
        accelZ: steamAccelToWire(-ay)
    )
}

// MARK: - Feature reports

/// Which way a configuration runs: quiet when Dish starts reading, restore
/// when it stops, or the pad stays mute as a keyboard and mouse.
package enum SteamConfigStage: CaseIterable, Equatable {
    case quiet
    case restore
}

/// {message id, payload length, payload}, the ids SDL's `ResetSteamController`
/// and `CloseSteamController` send.
let clearDigitalMappings: [UInt8] = [0x81, 0x00]
let loadDefaultSettings: [UInt8] = [0x8E, 0x00]
let defaultDigitalMappings: [UInt8] = [0x85, 0x00]
/// Loading the defaults leaves the right pad silent; SDL names its
/// absolute-mouse mode back.
let rightPadMouse: [UInt8] = [0x87, 0x03, 0x08, 0x00, 0x00]
