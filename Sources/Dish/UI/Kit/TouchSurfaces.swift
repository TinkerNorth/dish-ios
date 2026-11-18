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
        .onFingers(RoundedRectangle(cornerRadius: DishSize.mouseCorner)) { fingers, size in
            follow(leadFinger(fingers)?.location, in: size)
        }
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
            .onFingers(RoundedRectangle(cornerRadius: DishSize.mouseCorner)) { fingers, _ in follow(leadFinger(fingers)) }
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
        .onFingers(RoundedRectangle(cornerRadius: DishSize.mouseCorner)) { fingers, size in follow(fingers, in: size) }
    }

    /// The slots over the fingers: a finger keeps its slot, a new one takes
    /// a free slot or is left out while both are held. Lifts go first, so a
    /// slot that came free is taken in the same change.
    private func follow(_ fingers: [Finger], in size: CGSize) {
        let step = slotFingers(slotted, over: fingers, slots: touchpadSlots)
        slotted = step.slotted
        for slot in step.freed {
            onFinger(slot, nil)
        }
        for finger in step.moved {
            onFinger(finger.slot, across(finger.location, in: size))
        }
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
