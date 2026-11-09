// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

/// The buttons a pad holds down as the XUSB word itself: one bit per
/// `WireButton`, so a sample taken at controller polling rate never builds a
/// collection.
package struct WireButtonWord: Equatable, ExpressibleByArrayLiteral {
    package private(set) var rawValue: UInt16

    package init() {
        rawValue = 0
    }

    package init(_ buttons: [WireButton]) {
        rawValue = buttons.reduce(UInt16(0)) { word, button in word | button.bit }
    }

    package init(arrayLiteral buttons: WireButton...) {
        self.init(buttons)
    }

    package mutating func insert(_ button: WireButton) {
        rawValue |= button.bit
    }

    package mutating func remove(_ button: WireButton) {
        rawValue &= ~button.bit
    }

    package func contains(_ button: WireButton) -> Bool {
        rawValue & button.bit != 0
    }
}

/// One reading of a pad in the units the controller framework reports:
/// sticks -1...1 with y positive when the stick is pushed up, triggers
/// 0...1, and the buttons held down. The desktops' `GamepadSnapshot`.
package struct PadSample: Equatable {
    package internal(set) var leftX: Float
    package internal(set) var leftY: Float
    package internal(set) var rightX: Float
    package internal(set) var rightY: Float
    package internal(set) var leftTrigger: Float
    package internal(set) var rightTrigger: Float
    package internal(set) var pressed: WireButtonWord

    package init(
        leftX: Float = 0,
        leftY: Float = 0,
        rightX: Float = 0,
        rightY: Float = 0,
        leftTrigger: Float = 0,
        rightTrigger: Float = 0,
        pressed: WireButtonWord = WireButtonWord()
    ) {
        self.leftX = leftX
        self.leftY = leftY
        self.rightX = rightX
        self.rightY = rightY
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
        self.pressed = pressed
    }
}

/// A stick at full deflection on the wire: one short of `Int16.min` on the
/// negative side, as the XUSB convention has it.
package let wireStickMax: Float = 32767

/// The XUSB report a sample becomes: the button word, the triggers and the
/// four axes. The wire is up-positive like the framework, so Y passes
/// through with its sign. The desktops' `mapGamepad`.
package func wireReport(_ sample: PadSample) -> GamepadReport {
    GamepadReport(
        buttons: sample.pressed.rawValue,
        lt: scaleTrigger(sample.leftTrigger),
        rt: scaleTrigger(sample.rightTrigger),
        lx: scaleAxis(sample.leftX, max: wireStickMax),
        ly: scaleAxis(sample.leftY, max: wireStickMax),
        rx: scaleAxis(sample.rightX, max: wireStickMax),
        ry: scaleAxis(sample.rightY, max: wireStickMax)
    )
}

/// Scale a -1...1 axis into a clamped 16-bit signed integer.
package func scaleAxis(_ value: Float, max: Float) -> Int16 {
    Int16(clamping: Int(value * max))
}

/// Scale a 0...1 trigger into a clamped 8-bit unsigned integer.
package func scaleTrigger(_ value: Float) -> UInt8 {
    UInt8(clamping: Int((value * 255.0).rounded()))
}
