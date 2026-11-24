// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI
import UIKit

/// A finger on a control: which one, by the order it landed in, where it is
/// in the control's bounds (y down), where it landed and when.
struct Finger: Equatable {
    let id: Int
    let location: CGPoint
    let origin: CGPoint
    let landedAt: TimeInterval
}

/// A finger that lifted: where it landed, where it lifted, how long it stayed.
struct FingerLift: Equatable {
    let origin: CGPoint
    let lifted: CGPoint
    let held: TimeInterval
}

/// What a touch surface reports on every change: the fingers on it in the
/// order they landed, the lifts of this change, and the surface's size.
struct FingerChange: Equatable {
    let fingers: [Finger]
    let lifts: [FingerLift]
    let size: CGSize
}

/// A ledger after a lift, with the lift when the ledger knew the finger.
struct LedgerLift<Key: Hashable>: Equatable {
    let ledger: FingerLedger<Key>
    let lift: FingerLift?
}

/// The fingers on one control in the order they landed, each known to the
/// host by its own key; every move returns the next ledger.
struct FingerLedger<Key: Hashable>: Equatable {
    let fingers: [Finger]
    private let ids: [Key: Int]
    private let issued: Int

    init() {
        self.init(fingers: [], ids: [:], issued: 0)
    }

    private init(fingers: [Finger], ids: [Key: Int], issued: Int) {
        self.fingers = fingers
        self.ids = ids
        self.issued = issued
    }

    func landed(_ key: Key, at location: CGPoint, time: TimeInterval) -> FingerLedger {
        guard ids[key] == nil else { return moved(key, to: location) }
        let landed = fingers + [Finger(id: issued, location: location, origin: location, landedAt: time)]
        let known = ids.merging([key: issued]) { _, new in new }
        return FingerLedger(fingers: landed, ids: known, issued: issued + 1)
    }

    func moved(_ key: Key, to location: CGPoint) -> FingerLedger {
        guard let id = ids[key] else { return self }
        let moved = fingers.map { $0.id == id ? Finger(id: id, location: location, origin: $0.origin, landedAt: $0.landedAt) : $0 }
        return FingerLedger(fingers: moved, ids: ids, issued: issued)
    }

    /// The finger lifts at `location`; its lift says where it came from and
    /// how long it stayed.
    func lifted(_ key: Key, at location: CGPoint, time: TimeInterval) -> LedgerLift<Key> {
        guard let finger = fingers.first(where: { $0.id == ids[key] }) else { return LedgerLift(ledger: self, lift: nil) }
        let lift = FingerLift(origin: finger.origin, lifted: location, held: time - finger.landedAt)
        return LedgerLift(ledger: cancelled(key), lift: lift)
    }

    /// A finger the system took back leaves without a lift.
    func cancelled(_ key: Key) -> FingerLedger {
        guard let id = ids[key] else { return self }
        let left = fingers.filter { $0.id != id }
        let known = ids.filter { $0.key != key }
        return FingerLedger(fingers: left, ids: known, issued: issued)
    }
}

/// The finger a one-finger control follows: the first that landed, and the
/// next in line once it lifts.
func leadFinger(_ fingers: [Finger]) -> Finger? {
    fingers.first
}

/// Whether a button is held: while any finger is on it.
func holding(_ fingers: [Finger]) -> Bool {
    !fingers.isEmpty
}

/// Whether a lift was a tap: the finger stayed within `slop` of where it
/// landed and lifted within `window`.
func isTap(_ lift: FingerLift, slop: CGFloat, window: TimeInterval) -> Bool {
    let travel = hypot(lift.lifted.x - lift.origin.x, lift.lifted.y - lift.origin.y)
    return travel <= slop && lift.held <= window
}

/// How far the scroll strip's finger moved since the last report, in points
/// and down positive: a new finger starts from where it landed, and a lifted
/// one moved nothing.
func scrollStep(from last: Finger?, to lead: Finger?) -> CGFloat {
    guard let last, let lead, last.id == lead.id else { return 0 }
    return lead.location.y - last.location.y
}

/// A finger in one of the touchpad's slots.
struct SlotFinger: Equatable {
    let id: Int
    let slot: Int
    let location: CGPoint
}

/// The touchpad's slots after its fingers changed: the fingers in their
/// slots, the slots that came free, and the fingers to report, new or moved.
struct SlotStep: Equatable {
    let slotted: [SlotFinger]
    let freed: [Int]
    let moved: [SlotFinger]
}

/// The touchpad's `slots` over the fingers on it: a finger keeps its slot
/// while it is down, newcomers take the free slots in landing order.
func slotFingers(_ slotted: [SlotFinger], over fingers: [Finger], slots: Int) -> SlotStep {
    let down = Set(fingers.map(\.id))
    let kept = slotted.filter { down.contains($0.id) }
    let freed = slotted.filter { !down.contains($0.id) }.map(\.slot)
    let keptSlots = Dictionary(uniqueKeysWithValues: kept.map { ($0.id, $0.slot) })
    let free = (0 ..< slots).filter { slot in !kept.contains { $0.slot == slot } }
    let newcomers = fingers.filter { keptSlots[$0.id] == nil }.map(\.id)
    let taken = keptSlots.merging(zip(newcomers, free)) { kept, _ in kept }
    let next = fingers.compactMap { finger in taken[finger.id].map { SlotFinger(id: finger.id, slot: $0, location: finger.location) } }
    return SlotStep(slotted: next, freed: freed, moved: next.filter { !kept.contains($0) })
}

extension View {
    /// Lays a touch surface in `shape` over this view and reports its
    /// fingers on every landing, move and lift.
    func onFingers(_ shape: some Shape, _ onChange: @escaping @MainActor (FingerChange) -> Void) -> some View {
        overlay(FingerSurface(shape: shape, onChange: onChange))
    }
}

/// A control's touch surface: a view of UIKit's own over the control, in
/// its shape, handed each finger the moment it lands and every finger at
/// once, where a SwiftUI gesture waits on arbitration and can lose a finger.
private struct FingerSurface<Hit: Shape>: UIViewRepresentable {
    let shape: Hit
    let onChange: @MainActor (FingerChange) -> Void

    func makeUIView(context: Context) -> FingerSurfaceView {
        let view = FingerSurfaceView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: FingerSurfaceView, context: Context) {
        view.covers = { shape.path(in: $0).contains($1) }
        view.onChange = onChange
    }
}

/// The surface's view: the fingers on it in a ledger, reported on every
/// change; a cancelled touch leaves without a lift, and a view leaving the
/// window drops its fingers unreported, the model having released the
/// screen's by then.
private final class FingerSurfaceView: UIView {
    typealias Ledger = FingerLedger<ObjectIdentifier>

    /// Whether a point of the bounds is on the control.
    var covers: (CGRect, CGPoint) -> Bool = { _, _ in true }
    var onChange: @MainActor (FingerChange) -> Void = { _ in }
    private var ledger = Ledger()

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        covers(bounds, point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        apply(touches) { $0.landed(ObjectIdentifier($1), at: $1.location(in: self), time: $1.timestamp) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        apply(touches) { $0.moved(ObjectIdentifier($1), to: $1.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let lifts = inOrder(touches).map { touch in
            let lifted = ledger.lifted(ObjectIdentifier(touch), at: touch.location(in: self), time: touch.timestamp)
            ledger = lifted.ledger
            return lifted.lift
        }
        report(lifts: lifts.compactMap { $0 })
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        apply(touches) { $0.cancelled(ObjectIdentifier($1)) }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            ledger = Ledger()
        }
    }

    private func apply(_ touches: Set<UITouch>, _ move: (Ledger, UITouch) -> Ledger) {
        ledger = inOrder(touches).reduce(ledger, move)
        report(lifts: [])
    }

    private func inOrder(_ touches: Set<UITouch>) -> [UITouch] {
        touches.sorted { $0.timestamp < $1.timestamp }
    }

    private func report(lifts: [FingerLift]) {
        onChange(FingerChange(fingers: ledger.fingers, lifts: lifts, size: bounds.size))
    }
}
