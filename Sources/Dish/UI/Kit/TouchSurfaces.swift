// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// Where a finger is across a surface: -1...1 on each axis from its centre,
/// y down.
private func across(_ location: CGPoint, in size: CGSize) -> CGPoint {
    let width = max(size.width, 1)
    let height = max(size.height, 1)
    return CGPoint(x: location.x / width * 2 - 1, y: location.y / height * 2 - 1)
}

/// The touchpad's slots: the reducer's first and second finger.
private let touchpadSlots = 2

/// The mouse's move pad: one finger, a ring under it, and the hint at the
/// bottom. It reports where the finger is across the pad, nil on release.
struct MovePad: View {
    let hint: String
    let onMove: (CGPoint?) -> Void

    @State private var touch: CGPoint?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DishSize.mouseCorner).fill(DishTheme.surface)
            RoundedRectangle(cornerRadius: DishSize.mouseCorner).stroke(DishTheme.outline, lineWidth: DishSize.padStroke)
            VStack {
                Spacer()
                Text(hint).font(DishFont.detail).foregroundStyle(DishTheme.muted).padding(.bottom, DishSpace.s8)
            }
            if let touch {
                Circle()
                    .stroke(DishTheme.primary, lineWidth: DishSize.padHeldStroke)
                    .background(Circle().fill(DishTheme.padGlow))
                    .frame(width: DishSize.pointerRing, height: DishSize.pointerRing)
                    .position(touch)
            }
        }
        .onFingers(RoundedRectangle(cornerRadius: DishSize.mouseCorner)) { follow(leadFinger($0.fingers)?.location, in: $0.size) }
    }

    /// The lead finger's place across the pad, once per change.
    private func follow(_ location: CGPoint?, in size: CGSize) {
        guard location != touch else { return }
        touch = location
        onMove(location.map { across($0, in: size) })
    }
}

/// The mouse's scroll strip: ruled lines and its name between two
/// chevrons. It reports how far the finger moved since the last report, in
/// points, down positive.
struct ScrollStrip: View {
    let title: String
    let upSymbol: String
    let downSymbol: String
    let onScroll: (Double) -> Void

    @State private var last: Finger?

    var body: some View {
        RoundedRectangle(cornerRadius: DishSize.mouseCorner)
            .fill(last == nil ? DishTheme.surfaceDim : DishTheme.primaryFill)
            .overlay(RoundedRectangle(cornerRadius: DishSize.mouseCorner).stroke(DishTheme.outline, lineWidth: DishSize.padStroke))
            .overlay(label)
            .onFingers(RoundedRectangle(cornerRadius: DishSize.mouseCorner)) { follow(leadFinger($0.fingers)) }
    }

    private var label: some View {
        HStack(spacing: DishSpace.s6) {
            Image(systemName: upSymbol)
            Text(title)
            Image(systemName: downSymbol)
        }
        .font(DishFont.body)
        .foregroundStyle(DishTheme.muted)
    }

    /// The lead finger's travel since the last report; a finger that only
    /// landed or lifted scrolled nothing.
    private func follow(_ lead: Finger?) {
        let step = scrollStep(from: last, to: lead)
        last = lead
        if step != 0 { onScroll(Double(step)) }
    }
}

/// The touchpad's surface: up to two fingers, each in its own slot until it
/// lifts. It reports a slot's finger across the surface, nil on its lift.
struct TwoFingerSurface: View {
    let hint: String
    let onFinger: (Int, CGPoint?) -> Void

    @State private var slotted: [SlotFinger] = []

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DishSize.mouseCorner).fill(DishTheme.surface)
            RoundedRectangle(cornerRadius: DishSize.mouseCorner).stroke(DishTheme.outline, lineWidth: DishSize.padStroke)
            Text(hint).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
        .onFingers(RoundedRectangle(cornerRadius: DishSize.mouseCorner)) { follow($0) }
    }

    private func follow(_ change: FingerChange) {
        let step = slotFingers(slotted, over: change.fingers, slots: touchpadSlots)
        slotted = step.slotted
        report(step, in: change.size, to: onFinger)
    }
}

/// The gamepad's touchpad, a DualShock's or a DualSense's: up to two fingers
/// in their slots, each under a ring, and a tap on it for its click.
struct Trackpad: View {
    let size: CGSize
    let onFinger: (Int, CGPoint?) -> Void
    let onTap: () -> Void

    @State private var slotted: [SlotFinger] = []

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DishSize.padCorner).fill(DishTheme.surface)
            RoundedRectangle(cornerRadius: DishSize.padCorner).stroke(DishTheme.outline, lineWidth: DishSize.padStroke)
            ForEach(slotted, id: \.id) { finger in
                Circle()
                    .stroke(DishTheme.primary, lineWidth: DishSize.padHeldStroke)
                    .background(Circle().fill(DishTheme.padGlow))
                    .frame(width: DishSize.pointerRing, height: DishSize.pointerRing)
                    .position(finger.location)
            }
        }
        .frame(width: size.width, height: size.height)
        .onFingers(RoundedRectangle(cornerRadius: DishSize.padCorner)) { follow($0) }
    }

    private func follow(_ change: FingerChange) {
        let step = slotFingers(slotted, over: change.fingers, slots: touchpadSlots)
        slotted = step.slotted
        report(step, in: change.size, to: onFinger)
        for lift in change.lifts where isTap(lift, slop: DishSize.trackpadTapSlop, window: DishMotion.trackpadTapWindow) {
            onTap()
        }
    }
}

/// A slot step reported, the freed slots first so one that came free is
/// taken in the same change.
private func report(_ step: SlotStep, in size: CGSize, to onFinger: (Int, CGPoint?) -> Void) {
    for slot in step.freed {
        onFinger(slot, nil)
    }
    for finger in step.moved {
        onFinger(finger.slot, across(finger.location, in: size))
    }
}

/// The PC the play screens send to: the Satellite glyph, its name in mono,
/// a dot and the round trip.
struct PlayPill: View {
    let state: PlayPillState
    let symbol: String

    var body: some View {
        HStack(spacing: DishSpace.s4) {
            Image(systemName: symbol).foregroundStyle(DishTheme.brandGlyph)
            Text(state.pcName).font(DishFont.padLabel).foregroundStyle(DishTheme.onSurface)
            StatusMarkView(mark: state.mark)
            Text(state.detail).font(DishFont.monoDetail).foregroundStyle(state.detailColor)
        }
        .lineLimit(1)
        .padding(.horizontal, DishSpace.s8)
        .frame(height: DishSize.padRound)
        .background(Capsule().fill(DishTheme.surface))
        .overlay(Capsule().stroke(DishTheme.outline, lineWidth: DishSize.padStroke))
        .accessibilityElement(children: .combine)
    }
}
