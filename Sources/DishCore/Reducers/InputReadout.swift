// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The piece of dish-mac's input inspector the wire needs: the XUSB word's
// button table, the layout the report builders write, so nothing can name a
// bit the wire does not carry.

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
