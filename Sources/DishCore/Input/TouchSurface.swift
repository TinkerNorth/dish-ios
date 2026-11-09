// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

/// One of a touch surface's two finger slots, the two the wire carries.
package enum TouchSlot: Equatable {
    case first
    case second
}

/// One of the touchpad's two click zones under its surface.
package enum ClickZone: Equatable {
    case left
    case right
}

/// One touch on the on-screen touchpad or mouse. A finger's position is
/// across the surface, -1...1 on each axis from its centre, y down.
package enum TouchSurfaceEvent: Equatable {
    case finger(TouchSlot, x: Float, y: Float)
    case lifted(TouchSlot)
    /// The touchpad's click, pressed at the left or the right of the pad.
    case clickZone(ClickZone, held: Bool)
    /// The mouse's Left button: the pad's click.
    case leftButton(held: Bool)
    /// The mouse's Right button.
    case rightButton(held: Bool)
    /// The scroll strip moved under the finger by `points`, down positive.
    case scroll(points: Float)
    /// Every finger lifted at once: the screen closed or went away.
    case releaseAll
}

/// One finger slot's contact: whether it is down, its wire id (bumped on
/// each fresh contact) and where it is, in the surface's -1...1 units.
package struct TouchContact: Equatable {
    package var active = false
    package var id: UInt8 = 0
    package var x: Float = 0
    package var y: Float = 0

    /// The slot touched at `(x, y)`: a fresh contact takes the next id.
    func touched(x: Float, y: Float) -> TouchContact {
        TouchContact(active: true, id: active ? id : id &+ 1, x: x, y: y)
    }

    /// The slot lifted: it keeps its id for the next contact to bump.
    var lifted: TouchContact {
        TouchContact(active: false, id: id, x: x, y: y)
    }

    var finger: TouchpadFinger {
        guard active else { return TouchpadFinger(active: false, id: id, x: 0, y: 0) }
        return TouchpadFinger(active: true, id: id, x: scaleAxis(x, max: wireStickMax), y: scaleAxis(y, max: wireStickMax))
    }
}

/// The on-screen touchpad's or mouse's whole state: both fingers, the
/// click and the right button, which click zone holds the second slot,
/// and the scroll strip's travel short of a notch.
package struct TouchSurfaceState: Equatable {
    package internal(set) var first = TouchContact()
    package internal(set) var second = TouchContact()
    package internal(set) var leftHeld = false
    package internal(set) var rightHeld = false
    package internal(set) var heldZone: ClickZone?
    /// The second slot is the held zone's contact, not a finger's.
    package internal(set) var secondByZone = false
    package internal(set) var scrollRemainder: Float = 0

    package init() {}

    /// The sample the wire carries for this state, with a wheel event.
    package func sample(scrollV: Int16 = 0) -> TouchpadSample {
        TouchpadSample(
            finger0: first.finger,
            finger1: second.finger,
            buttonPressed: leftHeld || heldZone != nil,
            rightPressed: rightHeld,
            scrollV: scrollV
        )
    }

    fileprivate mutating func set(_ slot: TouchSlot, _ contact: TouchContact) {
        switch slot {
        case .first: first = contact
        case .second: second = contact
        }
    }

    /// The zone holds the click, and the second slot too while no finger has
    /// it, at its own half of the pad.
    fileprivate mutating func pressZone(_ zone: ClickZone) {
        heldZone = zone
        guard !second.active || secondByZone else { return }
        let x = zone == .left ? -zoneContactX : zoneContactX
        second = second.touched(x: x, y: zoneContactY)
        secondByZone = true
    }

    /// The held zone lets go of the click and of the slot it held.
    fileprivate mutating func releaseZone(_ zone: ClickZone) {
        guard heldZone == zone else { return }
        heldZone = nil
        guard secondByZone else { return }
        second = second.lifted
        secondByZone = false
    }

    fileprivate func contact(_ slot: TouchSlot) -> TouchContact {
        switch slot {
        case .first: first
        case .second: second
        }
    }
}

/// A state and the sample to send for it: the wheel event rides this one
/// sample alone, never a resend.
package struct TouchSurfaceStep: Equatable {
    package let state: TouchSurfaceState
    package let sample: TouchpadSample
}

/// The scroll strip's travel for one wheel notch.
package let scrollPointsPerNotch: Float = 24
/// One wheel notch on the wire.
package let wheelDeltaPerNotch = 120

/// Where a click zone's press lands on the pad: low on its own half, as a
/// thumb presses a DualSense's pad to click it.
private let zoneContactX: Float = 0.5
private let zoneContactY: Float = 0.6

/// How the touchpad's or the mouse's state moves under one touch.
package func reduceTouchSurface(_ state: TouchSurfaceState, _ event: TouchSurfaceEvent) -> TouchSurfaceStep {
    var next = state
    switch event {
    case let .finger(slot, x, y):
        next.set(slot, state.contact(slot).touched(x: x, y: y))
        if slot == .second { next.secondByZone = false }
    case let .lifted(slot):
        next.set(slot, state.contact(slot).lifted)
    case let .clickZone(zone, held):
        return zoneMoved(state, zone, held: held)
    case let .leftButton(held):
        next.leftHeld = held
    case let .rightButton(held):
        next.rightHeld = held
    case let .scroll(points):
        return scrolled(state, points: points)
    case .releaseAll:
        next = released(state)
    }
    return TouchSurfaceStep(state: next, sample: next.sample())
}

/// A zone pressed with the second slot free holds that slot at its half
/// of the pad, so the PC reads a left or a right click; its release lifts
/// the slot it held.
private func zoneMoved(_ state: TouchSurfaceState, _ zone: ClickZone, held: Bool) -> TouchSurfaceStep {
    var next = state
    switch held {
    case true: next.pressZone(zone)
    case false: next.releaseZone(zone)
    }
    return TouchSurfaceStep(state: next, sample: next.sample())
}

/// The strip's travel becomes whole notches, up positive; what is short of
/// a notch waits for the next move.
private func scrolled(_ state: TouchSurfaceState, points: Float) -> TouchSurfaceStep {
    var next = state
    let travel = state.scrollRemainder - points
    let notches = Int(travel / scrollPointsPerNotch)
    next.scrollRemainder = travel - Float(notches) * scrollPointsPerNotch
    let wheel = Int16(clamping: notches * wheelDeltaPerNotch)
    return TouchSurfaceStep(state: next, sample: next.sample(scrollV: wheel))
}

/// Everything lifted; each slot keeps its id, so the next contact is fresh.
private func released(_ state: TouchSurfaceState) -> TouchSurfaceState {
    var next = TouchSurfaceState()
    next.set(.first, state.first.lifted)
    next.set(.second, state.second.lifted)
    return next
}
