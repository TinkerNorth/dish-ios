// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI
import UIKit

/// A finger on a control: which one, by the order it landed in, and where
/// it is in the control's bounds, y down.
struct Finger: Equatable {
    let id: Int
    let location: CGPoint
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

    func landed(_ key: Key, at location: CGPoint) -> FingerLedger {
        guard ids[key] == nil else { return moved(key, to: location) }
        let landed = fingers + [Finger(id: issued, location: location)]
        let known = ids.merging([key: issued]) { _, new in new }
        return FingerLedger(fingers: landed, ids: known, issued: issued + 1)
    }

    func moved(_ key: Key, to location: CGPoint) -> FingerLedger {
        guard let id = ids[key] else { return self }
        let moved = fingers.map { $0.id == id ? Finger(id: id, location: location) : $0 }
        return FingerLedger(fingers: moved, ids: ids, issued: issued)
    }

    func lifted(_ key: Key) -> FingerLedger {
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
    /// Lays a touch surface in `shape` over this view and reports the
    /// fingers on it, in the order they landed, with the surface's size, on
    /// every landing, move and lift.
    func onFingers(_ shape: some Shape, _ onChange: @escaping @MainActor ([Finger], CGSize) -> Void) -> some View {
        overlay(FingerSurface(shape: shape, onChange: onChange))
    }
}

/// A control's touch surface: a view of UIKit's own over the control, in
/// its shape, handed each finger the moment it lands and every finger at
/// once, where a SwiftUI gesture waits on arbitration and can lose a finger.
private struct FingerSurface<Hit: Shape>: UIViewRepresentable {
    let shape: Hit
    let onChange: @MainActor ([Finger], CGSize) -> Void

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
/// change; a cancelled touch lifts, and a view leaving the window drops its
/// fingers unreported, the model having released the screen's by then.
private final class FingerSurfaceView: UIView {
    /// Whether a point of the bounds is on the control.
    var covers: (CGRect, CGPoint) -> Bool = { _, _ in true }
    var onChange: @MainActor ([Finger], CGSize) -> Void = { _, _ in }
    private var ledger = FingerLedger<ObjectIdentifier>()

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        covers(bounds, point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        apply(touches) { $0.landed(ObjectIdentifier($1), at: $1.location(in: self)) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        apply(touches) { $0.moved(ObjectIdentifier($1), to: $1.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        apply(touches) { $0.lifted(ObjectIdentifier($1)) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        apply(touches) { $0.lifted(ObjectIdentifier($1)) }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { ledger = FingerLedger() }
    }

    private func apply(_ touches: Set<UITouch>, _ move: (FingerLedger<ObjectIdentifier>, UITouch) -> FingerLedger<ObjectIdentifier>) {
        ledger = touches.sorted { $0.timestamp < $1.timestamp }.reduce(ledger, move)
        onChange(ledger.fingers, bounds.size)
    }
}
