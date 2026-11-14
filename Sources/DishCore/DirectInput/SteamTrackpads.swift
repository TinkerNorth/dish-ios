// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// A Steam Controller's two trackpads onto the wire, by the slot's pick, as
// dish-mac's `SteamTrackpads.swift` routes them: the 2015 right pad as the
// right stick with its click as R3, both pads on the one touch surface, or
// nowhere, with the clicks on the extended-buttons word wherever nothing
// else takes them. The decoders hand the router raw pad samples; the router
// owns the 2015 right stick and the touch surface, and builds nothing per
// report. iOS sends no pointer frame from a pad (Tests/PARITY.md), so a
// mouse pick routes as off.

import Foundation

/// Which trackpads a pad has: none, the 2015 pad's (its right pad is the
/// right stick until picked otherwise), or the 2026 pad's two beside a real
/// right stick.
package enum SteamTrackpads: Hashable {
    case none
    case rightStickByDefault
    case twoPads
}

/// A trackpad as its decoder reads it: up-positive, the full int16 range,
/// SDL's shell rotation applied on the 2015 pad.
package struct SteamPadSample: Equatable {
    package var active: Bool
    package var x: Int16
    package var y: Int16
    package var clicked: Bool

    package init(active: Bool = false, x: Int16 = 0, y: Int16 = 0, clicked: Bool = false) {
        self.active = active
        self.x = x
        self.y = y
        self.clicked = clicked
    }
}

package struct SteamPads: Equatable {
    package var left: SteamPadSample
    package var right: SteamPadSample

    package init(left: SteamPadSample = SteamPadSample(), right: SteamPadSample = SteamPadSample()) {
        self.left = left
        self.right = right
    }
}

/// What the router lands on the touch surface: two finger slots (the link
/// stamps their wire ids) and the surface's click.
package struct SteamSurface: Equatable {
    package let finger0: TouchpadFinger
    package let finger1: TouchpadFinger
    package let clicked: Bool

    package init(finger0: TouchpadFinger, finger1: TouchpadFinger, clicked: Bool) {
        self.finger0 = finger0
        self.finger1 = finger1
        self.clicked = clicked
    }

    /// Nothing on the surface.
    package static let lifted = SteamSurface(finger0: .none, finger1: .none, clicked: false)
}

/// One report through the router: the XUSB state with the pads' share of it
/// and the surface beside it.
package struct SteamRouted: Equatable {
    package let report: GamepadReport
    package let surface: SteamSurface

    package init(report: GamepadReport, surface: SteamSurface) {
        self.report = report
        self.surface = surface
    }
}

private enum SteamSurfaceLayout {
    /// Pad mode's halves: each pad's full range folded onto one side.
    static let halfSurface: Int32 = 16384
    static let leftFingerId: UInt8 = 0
    static let rightFingerId: UInt8 = 1
}

/// The 2015 right pad is the right stick unless the pick says otherwise, so
/// the router owns those axes on that model; the 2026 pad's real stick is
/// the decoder's and untouched here.
package func routeSteamTrackpads(pick: TouchpadPick, trackpads: SteamTrackpads, pads: SteamPads, report: GamepadReport) -> SteamRouted {
    let rightPadIsTheStick = trackpads == .rightStickByDefault
    let base = rightPadIsTheStick ? report.withRightStick(x: 0, y: 0) : report
    switch pick {
    case .stick: return rightPadIsTheStick ? routeAsStick(pads, base) : routeAsOff(pads, base)
    case .pad: return routeAsPad(pads, base)
    case .mouse, .off: return routeAsOff(pads, base)
    }
}

extension GamepadReport {
    /// The report with its right stick moved, and buttons added to its two words.
    func withRightStick(x: Int16, y: Int16, pressing button: UInt16 = 0, extending ext: UInt32 = 0) -> GamepadReport {
        GamepadReport(buttons: buttons | button, lt: lt, rt: rt, lx: lx, ly: ly, rx: x, ry: y, extButtons: extButtons | ext)
    }

    /// The report with extended buttons added to its word.
    func addingExtButtons(_ ext: UInt32) -> GamepadReport {
        withRightStick(x: rx, y: ry, extending: ext)
    }
}

/// Pads are up-positive and the wire's touch surface is +y down; -(-32768)
/// has no int16, so it clamps.
private func padYToWire(_ y: Int16) -> Int16 {
    Int16(clamping: -Int32(y))
}

private func finger(_ id: UInt8, _ pad: SteamPadSample, x: Int16) -> TouchpadFinger {
    guard pad.active else { return .none }
    return TouchpadFinger(active: true, id: id, x: x, y: padYToWire(pad.y))
}

private func padClickBits(left: Bool, right: Bool) -> UInt32 {
    let leftBit = left ? ProtocolConstants.extButtonLeftPadClick : 0
    let rightBit = right ? ProtocolConstants.extButtonRightPadClick : 0
    return leftBit | rightBit
}

private func routeAsStick(_ pads: SteamPads, _ report: GamepadReport) -> SteamRouted {
    let rx = pads.right.active ? pads.right.x : 0
    let ry = pads.right.active ? pads.right.y : 0
    let rightThumb = pads.right.clicked ? WireButton.rightThumb.bit : 0
    let leftClick = padClickBits(left: pads.left.clicked, right: false)
    return SteamRouted(report: report.withRightStick(x: rx, y: ry, pressing: rightThumb, extending: leftClick), surface: .lifted)
}

private func routeAsPad(_ pads: SteamPads, _ report: GamepadReport) -> SteamRouted {
    let leftX = Int16(clamping: Int32(pads.left.x) / 2 - SteamSurfaceLayout.halfSurface)
    let rightX = Int16(clamping: Int32(pads.right.x) / 2 + SteamSurfaceLayout.halfSurface)
    let surface = SteamSurface(
        finger0: finger(SteamSurfaceLayout.leftFingerId, pads.left, x: leftX),
        finger1: finger(SteamSurfaceLayout.rightFingerId, pads.right, x: rightX),
        clicked: pads.left.clicked || pads.right.clicked
    )
    return SteamRouted(report: report, surface: surface)
}

private func routeAsOff(_ pads: SteamPads, _ report: GamepadReport) -> SteamRouted {
    let clicks = padClickBits(left: pads.left.clicked, right: pads.right.clicked)
    return SteamRouted(report: report.addingExtButtons(clicks), surface: .lifted)
}
