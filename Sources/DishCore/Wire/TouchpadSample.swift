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
/// The on-screen mouse adds the right button and a wheel event, which only
/// the version-2 POINTER shape carries (`Encoders.pointerPayload`); a pad's
/// own touchpad leaves both at rest.
package struct TouchpadSample: Equatable {
    package let finger0: TouchpadFinger
    package let finger1: TouchpadFinger
    package let buttonPressed: Bool
    package let rightPressed: Bool
    /// A wheel event in 120ths of a notch, up positive; 0 on a resend.
    package let scrollV: Int16

    package init(finger0: TouchpadFinger, finger1: TouchpadFinger, buttonPressed: Bool, rightPressed: Bool = false, scrollV: Int16 = 0) {
        self.finger0 = finger0
        self.finger1 = finger1
        self.buttonPressed = buttonPressed
        self.rightPressed = rightPressed
        self.scrollV = scrollV
    }

    /// Nothing touching, nothing held.
    package static let idle = TouchpadSample(finger0: .none, finger1: .none, buttonPressed: false)
}
