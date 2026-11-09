// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

/// One finger slot of a touchpad sample: whether it is down, its monotonic
/// tracking id, and its normalised int16 position (contract §0x000C).
package struct TouchpadFinger: Equatable {
    package let active: Bool
    package let id: UInt8
    package let x: Int16
    package let y: Int16

    package init(active: Bool, id: UInt8, x: Int16, y: Int16) {
        self.active = active
        self.id = id
        self.x = x
        self.y = y
    }

    /// A lifted finger with no id: what an absent slot carries.
    package static let none = TouchpadFinger(active: false, id: 0, x: 0, y: 0)
}

/// A touchpad sample as MSG_TOUCHPAD carries it: two finger slots and the
/// clickable-pad button. The sender stamps `eventTimeMs` separately, since the
/// stamp is taken at publish time rather than being part of the sample.
package struct TouchpadSample: Equatable {
    package let finger0: TouchpadFinger
    package let finger1: TouchpadFinger
    package let buttonPressed: Bool

    package init(finger0: TouchpadFinger, finger1: TouchpadFinger, buttonPressed: Bool) {
        self.finger0 = finger0
        self.finger1 = finger1
        self.buttonPressed = buttonPressed
    }
}
