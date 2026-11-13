// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

/// One full-state gamepad snapshot in the XUSB layout MSG_INPUT carries:
/// the 16-bit button word, the two analog triggers and the four stick axes,
/// plus the extended-buttons word (`ProtocolConstants.extButton*`) a session
/// settled on version 4 sends behind them. A report is never a delta.
package struct GamepadReport: Equatable {
    package let buttons: UInt16
    package let lt: UInt8
    package let rt: UInt8
    package let lx: Int16
    package let ly: Int16
    package let rx: Int16
    package let ry: Int16
    package let extButtons: UInt32

    package init(
        buttons: UInt16 = 0,
        lt: UInt8 = 0,
        rt: UInt8 = 0,
        lx: Int16 = 0,
        ly: Int16 = 0,
        rx: Int16 = 0,
        ry: Int16 = 0,
        extButtons: UInt32 = 0
    ) {
        self.buttons = buttons
        self.lt = lt
        self.rt = rt
        self.lx = lx
        self.ly = ly
        self.rx = rx
        self.ry = ry
        self.extButtons = extButtons
    }

    /// Every button up, every axis centred: what a release-all sends.
    package static let released = GamepadReport()
}
