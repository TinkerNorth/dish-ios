// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// One of the on-screen gamepad's two sticks.
package enum PadStick: Equatable {
    case left
    case right
}

/// One of the on-screen gamepad's two trigger rails.
package enum PadTrigger: Equatable {
    case left
    case right
}

/// One touch on the on-screen gamepad as the screen reports it. A stick or
/// the d-pad reports the finger's offset from the control's centre in units
/// of its radius, with y down as on the screen; a rail reports how far down
/// it the finger is, 0 at its top and 1 at its bottom.
package enum OnScreenPadEvent: Equatable {
    case press(WireButton)
    case release(WireButton)
    case stick(PadStick, x: Float, y: Float)
    case stickReleased(PadStick)
    case trigger(PadTrigger, railY: Float)
    case triggerReleased(PadTrigger)
    case dpad(x: Float, y: Float)
    case dpadReleased
    /// Every finger lifted at once: the screen closed or went away.
    case releaseAll
}

/// The on-screen gamepad's whole state: what the fingers hold, as the pad
/// sample a physical pad would read, and whether its triggers are analog
/// (a Switch Pro's are not, so a rail is a full press).
package struct OnScreenPadState: Equatable {
    package internal(set) var sample = PadSample()
    package var analogTriggers = true

    package init(analogTriggers: Bool = true) {
        self.analogTriggers = analogTriggers
    }

    /// The full-state report the wire carries for this state.
    package var report: GamepadReport {
        wireReport(sample)
    }
}

/// How the on-screen gamepad's state moves under one touch. The receiver
/// keeps its own dead zones, so a stick here has none: centre-origin,
/// clamped to its radius, and nothing else (Android's `computeStickAxes`).
package func reduceOnScreenPad(_ state: OnScreenPadState, _ event: OnScreenPadEvent) -> OnScreenPadState {
    var next = state
    switch event {
    case let .press(button): next.sample.pressed.insert(button)
    case let .release(button): next.sample.pressed.remove(button)
    case let .stick(stick, x, y): next.sample.move(stick, to: stickAxes(x: x, y: y))
    case let .stickReleased(stick): next.sample.move(stick, to: .centre)
    case let .trigger(trigger, railY): next.sample.pull(trigger, triggerRailValue(railY: railY, analog: state.analogTriggers))
    case let .triggerReleased(trigger): next.sample.pull(trigger, 0)
    case let .dpad(x, y): next.sample.hold(dpadDirections(x: x, y: y))
    case .dpadReleased: next.sample.hold([])
    case .releaseAll: next = OnScreenPadState(analogTriggers: state.analogTriggers)
    }
    return next
}

/// A stick's position in the framework's units: -1...1 on each axis, y up.
package struct StickAxes: Equatable {
    package let x: Float
    package let y: Float

    package static let centre = StickAxes(x: 0, y: 0)
}

/// A finger's offset from a stick's centre, in radii with y down, as the
/// stick reads it: clamped to the rim along its own direction, y flipped up.
package func stickAxes(x: Float, y: Float) -> StickAxes {
    let distance = min((x * x + y * y).squareRoot(), 1)
    guard distance > 0 else { return .centre }
    let angle = atan2f(y, x)
    return StickAxes(x: distance * cosf(angle), y: -(distance * sinf(angle)))
}

/// The top quarter of a rail is a full pull and a plain tap target.
package let triggerFullZone: Float = 0.25

/// How far a trigger is pulled for a finger `railY` down its rail: full in
/// the top quarter, ramping to nothing at the bottom edge, clamped at both
/// ends. A digital trigger is a full press wherever it is touched.
package func triggerRailValue(railY: Float, analog: Bool) -> Float {
    guard analog else { return 1 }
    let clamped = min(max(railY, 0), 1)
    guard clamped > triggerFullZone else { return 1 }
    return (1 - clamped) / (1 - triggerFullZone)
}

/// The share of the major axis the minor one needs before the d-pad reads
/// a diagonal (Android's `DPAD_DIAGONAL_THRESHOLD`).
package let dpadDiagonalThreshold: Float = 0.3

/// The directions a finger at `(x, y)` from the d-pad's centre holds, y
/// down: the nearer arm, or both arms of a diagonal once the minor axis is
/// at least `dpadDiagonalThreshold` of the major one. The dead centre holds
/// none.
package func dpadDirections(x: Float, y: Float) -> WireButtonWord {
    let major = max(abs(x), abs(y))
    guard major > 0 else { return [] }
    let horizontal: WireButton = x > 0 ? .dpadRight : .dpadLeft
    let vertical: WireButton = y > 0 ? .dpadDown : .dpadUp
    let diagonal = min(abs(x), abs(y)) / major >= dpadDiagonalThreshold
    guard !diagonal else { return [horizontal, vertical] }
    return abs(x) >= abs(y) ? [horizontal] : [vertical]
}

private let dpadButtons: [WireButton] = [.dpadUp, .dpadDown, .dpadLeft, .dpadRight]

private extension PadSample {
    mutating func move(_ stick: PadStick, to axes: StickAxes) {
        switch stick {
        case .left:
            leftX = axes.x
            leftY = axes.y
        case .right:
            rightX = axes.x
            rightY = axes.y
        }
    }

    mutating func pull(_ trigger: PadTrigger, _ value: Float) {
        switch trigger {
        case .left: leftTrigger = value
        case .right: rightTrigger = value
        }
    }

    /// The d-pad's four bits become exactly `directions`.
    mutating func hold(_ directions: WireButtonWord) {
        for button in dpadButtons {
            pressed.remove(button)
        }
        for button in dpadButtons where directions.contains(button) {
            pressed.insert(button)
        }
    }
}
