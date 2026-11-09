// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// One pad's input on its way out. It is published on the one thread the
/// pad's handlers run on, its GameController queue, which alone moves the
/// route it holds, the latch, the motion gate and the touch ids; the main
/// actor sets the dead zones in an atomic word, hands the route over through
/// a mailbox, and reads what the pad last sent from the record under its
/// seqlock. A report takes no lock and builds nothing. Every field is an
/// atomic word or a `let`, so the compiler accepts the feed as `Sendable`
/// with nothing promised past it.
package final class PadFeed: Sendable {
    package let deviceId: String
    package let record = PadRecord()
    /// The pad's dead zones, packed: written by the main actor.
    private let deadzones = AtomicWord()
    private let routeMail = Mailbox<RouteBox>()
    private let lastInputMs: AtomicInt
    private let sent: AtomicCounter

    /// The publishing thread's own: the route it took from the mailbox, the
    /// last report it let through, when it last let motion through, and both
    /// fingers' contacts.
    private let route = ReaderHeld<RouteBox>()
    private let latchLow = AtomicWord()
    private let latchHigh = AtomicWord()
    private let latched = AtomicWord()
    private let lastMotionNs = AtomicWord(noMotionYet)
    private let fingers = AtomicWord()

    package init(deviceId: String, lastInputMs: AtomicInt, sent: AtomicCounter) {
        self.deviceId = deviceId
        self.lastInputMs = lastInputMs
        self.sent = sent
    }

    // MARK: - The main actor's side

    package func useDeadzones(_ zones: GamepadInputProcessor.Deadzones) {
        deadzones.store(zones.packed)
    }

    /// The pad's route from now on; nil sends nothing.
    package func post(route: Route?) {
        routeMail.post(RouteBox(route))
    }

    // MARK: - The publishing thread's side

    /// Filter a full-state report through the dead zones, record it, stamp
    /// the moment and send it.
    package func publish(_ state: GamepadReport) {
        let filtered = applyDeadzones(state, GamepadInputProcessor.Deadzones(packed: deadzones.loadRelaxed()))
        record.write(raw: state, filtered: filtered)
        lastInputMs.set(Int(uptimeNs() / 1_000_000))
        guard let route = currentRoute() else { return }
        sent.increment()
        route.sink.send(filtered, slot: route.slot)
    }

    /// GameController calls a pad's handler for each element that moves, so
    /// one mapped report can come again and again: only a change from the
    /// last one let through is published.
    package func publishIfChanged(_ state: GamepadReport) {
        let low = state.packedLow
        let high = state.packedHigh
        let repeated = latched.loadRelaxed() != 0 && latchLow.loadRelaxed() == low && latchHigh.loadRelaxed() == high
        guard !repeated else { return }
        latchLow.storeRelaxed(low)
        latchHigh.storeRelaxed(high)
        latched.storeRelaxed(1)
        publish(state)
    }

    /// Forward a wire-scaled sample, thinned to the rate limit, measured
    /// from the last emitted sample so a stream of drops never pushes the
    /// deadline forward.
    package func publishMotion(_ sample: MotionSample, nowNs: UInt64 = uptimeNs()) {
        guard admitMotion(nowNs: nowNs) else { return }
        record.write(motion: sample)
        guard let route = currentRoute(), route.flags.motion else { return }
        route.sink.send(sample, slot: route.slot)
    }

    package func publishTouchpad(_ sample: TouchpadSample) {
        record.write(touch: sample)
        guard let route = currentRoute(), route.flags.touchpad else { return }
        route.sink.send(sample, slot: route.slot)
    }

    /// Advance both fingers' ids for one sample and return the ids to stamp
    /// on the wire: each bumps on its finger's fresh contact.
    package func advanceTouchIds(finger0Active: Bool, finger1Active: Bool) -> (finger0: UInt8, finger1: UInt8) {
        let previous = FingerContacts(packed: fingers.loadRelaxed())
        let next = previous.advanced(finger0Active: finger0Active, finger1Active: finger1Active)
        fingers.storeRelaxed(next.packed)
        return (next.finger0.id, next.finger1.id)
    }

    private func currentRoute() -> Route? {
        if let fresh = routeMail.take() { route.replace(with: fresh) }
        return route.current?.route
    }

    /// Whether this sample is let through: the first one is, and after it
    /// one per rate-limit window, never one whose clock did not advance.
    private func admitMotion(nowNs: UInt64) -> Bool {
        let previous = lastMotionNs.loadRelaxed()
        let now = Int64(bitPattern: nowNs)
        guard previous != noMotionYet else {
            lastMotionNs.storeRelaxed(now)
            return true
        }
        guard now > previous, UInt64(now - previous) >= GamepadInputProcessor.motionMinIntervalNs else { return false }
        lastMotionNs.storeRelaxed(now)
        return true
    }
}

/// The motion gate before its first sample.
private let noMotionYet: Int64 = -1

/// The uptime clock in nanoseconds, the stamp a pad's input is measured by.
package func uptimeNs() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
}

/// One finger's last-seen contact and its current wire id.
struct FingerContact: Equatable {
    var wasActive = false
    var id: UInt8 = 0

    func advanced(active: Bool) -> FingerContact {
        FingerContact(wasActive: active, id: nextTouchpadTrackingId(wasActive: wasActive, isActive: active, current: id))
    }
}

/// Both fingers' contacts in one word: each finger's id and whether it was down.
struct FingerContacts: Equatable {
    var finger0 = FingerContact()
    var finger1 = FingerContact()

    init(finger0: FingerContact, finger1: FingerContact) {
        self.finger0 = finger0
        self.finger1 = finger1
    }

    init(packed word: Int64) {
        finger0 = FingerContact(wasActive: word & 1 != 0, id: UInt8(truncatingIfNeeded: word >> 1))
        finger1 = FingerContact(wasActive: word & 1 << 9 != 0, id: UInt8(truncatingIfNeeded: word >> 10))
    }

    var packed: Int64 {
        (finger0.wasActive ? 1 : 0) | Int64(finger0.id) << 1 | (finger1.wasActive ? 1 << 9 : 0) | Int64(finger1.id) << 10
    }

    func advanced(finger0Active: Bool, finger1Active: Bool) -> FingerContacts {
        FingerContacts(finger0: finger0.advanced(active: finger0Active), finger1: finger1.advanced(active: finger1Active))
    }
}
