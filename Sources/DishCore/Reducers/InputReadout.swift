// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The pieces of dish-mac's input inspector this client needs: the XUSB
// word's button table, the layout the report builders write, so nothing can
// name a bit the wire does not carry; and a stick axis in the inspectors'
// units, which the bench's stick tests read.

import Foundation

public enum WireButton: CaseIterable, Equatable, Sendable {
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case start
    case back
    case leftThumb
    case rightThumb
    case leftShoulder
    case rightShoulder
    case guide
    case micMute
    case faceA
    case faceB
    case faceX
    case faceY

    /// The XUSB bit, 0x0800 being the DualSense mic-mute button protocol 2
    /// put in the word's one unassigned slot.
    public var bit: UInt16 {
        switch self {
        case .dpadUp: 0x0001
        case .dpadDown: 0x0002
        case .dpadLeft: 0x0004
        case .dpadRight: 0x0008
        case .start: 0x0010
        case .back: 0x0020
        case .leftThumb: 0x0040
        case .rightThumb: 0x0080
        case .leftShoulder: 0x0100
        case .rightShoulder: 0x0200
        case .guide: 0x0400
        case .micMute: 0x0800
        case .faceA: 0x1000
        case .faceB: 0x2000
        case .faceX: 0x4000
        case .faceY: 0x8000
        }
    }
}

/// The inspectors' units for what a pad sent.
public enum InputReadout {
    /// A stick axis as a fraction of full deflection, -1...1, divided by
    /// 32768 like dish-android's and dish-mac's inspectors, so every client
    /// reads one sample the same.
    public static let stickScale: Float = 32768

    public static func stickFraction(_ axis: Int16) -> Float {
        Float(axis) / stickScale
    }

    public static func stickSample(x: Int16, y: Int16) -> StickSample {
        StickSample(x: stickFraction(x), y: stickFraction(y))
    }
}
