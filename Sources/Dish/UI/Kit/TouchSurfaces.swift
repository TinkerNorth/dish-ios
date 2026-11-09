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

/// The mouse's move pad: one finger, a ring under it, and the hint at the
/// bottom. It reports where the finger is across the pad, nil on release.
struct MovePad: View {
    let hint: String
    let onMove: (CGPoint?) -> Void

    @GestureState private var touch: CGPoint?

    var body: some View {
        GeometryReader { geometry in
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
            .contentShape(RoundedRectangle(cornerRadius: DishSize.mouseCorner))
            .gesture(DragGesture(minimumDistance: 0).updating($touch) { value, state, _ in state = value.location })
            .onChange(of: touch) { onMove($1.map { across($0, in: geometry.size) }) }
        }
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

    @GestureState private var travel: CGFloat?

    var body: some View {
        RoundedRectangle(cornerRadius: DishSize.mouseCorner)
            .fill(travel == nil ? DishTheme.surfaceDim : DishTheme.primaryFill)
            .overlay(RoundedRectangle(cornerRadius: DishSize.mouseCorner).stroke(DishTheme.outline, lineWidth: DishSize.padStroke))
            .overlay(label)
            .contentShape(RoundedRectangle(cornerRadius: DishSize.mouseCorner))
            .gesture(DragGesture(minimumDistance: 0).updating($travel) { value, state, _ in state = value.translation.height })
            .onChange(of: travel) { moved(from: $0, to: $1) }
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

    /// A new finger starts from where it landed; a lifted one moved nothing.
    private func moved(from old: CGFloat?, to new: CGFloat?) {
        guard let new else { return }
        onScroll(Double(new - (old ?? 0)))
    }
}

/// The touchpad's surface: up to two fingers, each in its own slot until it
/// lifts. It reports a slot's finger across the surface, nil on its lift.
struct TwoFingerSurface: View {
    let hint: String
    let onFinger: (Int, CGPoint?) -> Void

    @State private var slots: [SpatialEventCollection.Event.ID: Int] = [:]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: DishSize.mouseCorner).fill(DishTheme.surface)
                RoundedRectangle(cornerRadius: DishSize.mouseCorner).stroke(DishTheme.outline, lineWidth: DishSize.padStroke)
                Text(hint).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
            .contentShape(RoundedRectangle(cornerRadius: DishSize.mouseCorner))
            .gesture(
                SpatialEventGesture()
                    .onChanged { track($0, in: geometry.size) }
                    .onEnded { track($0, in: geometry.size) }
            )
        }
    }

    private func track(_ events: SpatialEventCollection, in size: CGSize) {
        for event in events {
            switch event.phase {
            case .active: moved(event, in: size)
            case .ended, .cancelled: lifted(event.id)
            @unknown default: lifted(event.id)
            }
        }
    }

    /// A finger keeps its slot; a new one takes a free slot, or is ignored
    /// while both are held.
    private func moved(_ event: SpatialEventCollection.Event, in size: CGSize) {
        let taken = Set(slots.values)
        guard let slot = slots[event.id] ?? [0, 1].first(where: { !taken.contains($0) }) else { return }
        slots[event.id] = slot
        onFinger(slot, across(event.location, in: size))
    }

    private func lifted(_ id: SpatialEventCollection.Event.ID) {
        guard let slot = slots.removeValue(forKey: id) else { return }
        onFinger(slot, nil)
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
            StatusDot(color: state.dot)
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
