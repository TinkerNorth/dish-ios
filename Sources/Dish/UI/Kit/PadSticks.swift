// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// A stick: a round base and a thumb that follows the finger to the rim.
/// It reports the finger's offset from its centre in radii, y down, and nil
/// when the finger lifts; the reducer clamps it. The page hands it the
/// base's and the thumb's diameters, the phone's or an iPad's.
struct PadStickControl: View {
    let base: CGFloat
    let thumb: CGFloat
    let onMove: (CGVector?) -> Void

    @GestureState private var touch: CGPoint?

    var body: some View {
        ZStack {
            Circle().fill(DishTheme.surface)
            Circle().stroke(DishTheme.outline, lineWidth: DishSize.padStroke)
            Circle()
                .fill(DishTheme.padThumb)
                .overlay(Circle().stroke(touch == nil ? DishTheme.outline : DishTheme.primary, lineWidth: DishSize.padHeldStroke))
                .shadow(color: touch == nil ? Color.clear : DishTheme.padGlow, radius: DishSize.padGlow)
                .frame(width: thumb, height: thumb)
                .offset(thumbOffset)
        }
        .frame(width: base, height: base)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).updating($touch) { value, state, _ in state = value.location })
        .onChange(of: touch) { onMove(offset(of: $1)) }
    }

    private var radius: CGFloat {
        base / 2
    }

    private func offset(of location: CGPoint?) -> CGVector? {
        location.map { CGVector(dx: ($0.x - radius) / radius, dy: ($0.y - radius) / radius) }
    }

    /// The thumb stays inside the base, along the finger's direction.
    private var thumbOffset: CGSize {
        guard let vector = offset(of: touch) else { return .zero }
        let travel = radius - thumb / 2
        let length = max(hypot(vector.dx, vector.dy), 1)
        return CGSize(width: vector.dx / length * travel, height: vector.dy / length * travel)
    }
}

/// A trigger rail along a side: its name at the top, filled from the
/// bottom as far as the finger has pulled it. It reports how far down the
/// rail the finger is, 0 at the top and 1 at the bottom, and nil on release.
struct TriggerRail: View {
    let title: String
    /// The rail's breadth; it runs the height it is given.
    let breadth: CGFloat
    let onPull: (Double?) -> Void

    @GestureState private var touch: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Capsule().fill(DishTheme.surface)
                Rectangle()
                    .fill(DishTheme.primaryFill)
                    .frame(height: geometry.size.height * fill(height: geometry.size.height))
                Capsule().stroke(touch == nil ? DishTheme.outline : DishTheme.primary, lineWidth: DishSize.padStroke)
                VStack {
                    Text(title).font(DishFont.padLabel).foregroundStyle(DishTheme.onSurface).padding(.top, DishSpace.s8)
                    Spacer()
                }
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).updating($touch) { value, state, _ in state = value.location })
            .onChange(of: touch) { onPull(railY($1, height: geometry.size.height)) }
        }
        .frame(width: breadth)
    }

    private func railY(_ location: CGPoint?, height: CGFloat) -> Double? {
        location.map { Double($0.y / max(height, 1)) }
    }

    /// How much of the rail reads pulled: up to the finger, clamped.
    private func fill(height: CGFloat) -> CGFloat {
        guard let pulled = railY(touch, height: height) else { return 0 }
        return CGFloat(min(max(1 - pulled, 0), 1))
    }
}

/// The d-pad: a cross of four arms under one finger, which can slide from
/// arm to arm. It reports the finger's offset from the centre in arm
/// lengths, y down, and nil on release; the reducer reads the directions.
struct DirectionPad: View {
    /// One arm's side; the cross is three arms across.
    let key: CGFloat
    let onMove: (CGVector?) -> Void

    @GestureState private var touch: CGPoint?

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                arm("chevron.up", lit: lit.up)
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
            GridRow {
                arm("chevron.left", lit: lit.left)
                Rectangle().fill(DishTheme.surfaceDim).frame(width: key, height: key)
                arm("chevron.right", lit: lit.right)
            }
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                arm("chevron.down", lit: lit.down)
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
        }
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).updating($touch) { value, state, _ in state = value.location })
        .onChange(of: touch) { onMove(offset(of: $1)) }
    }

    private var side: CGFloat {
        key * 3
    }

    private func arm(_ symbol: String, lit: Bool) -> some View {
        Image(systemName: symbol)
            .font(DishFont.headline)
            .foregroundStyle(lit ? DishTheme.primary : DishTheme.muted)
            .frame(width: key, height: key)
            .background(RoundedRectangle(cornerRadius: DishSize.padCorner).fill(lit ? DishTheme.primaryFill : DishTheme.surfaceDim))
            .overlay(RoundedRectangle(cornerRadius: DishSize.padCorner).stroke(
                lit ? DishTheme.primary : DishTheme.outline,
                lineWidth: DishSize.padStroke
            ))
    }

    private func offset(of location: CGPoint?) -> CGVector? {
        let half = side / 2
        return location.map { CGVector(dx: ($0.x - half) / half, dy: ($0.y - half) / half) }
    }

    /// The arms the finger leans on, lit as the reducer reads them: the
    /// nearer one, or both of a diagonal.
    private var lit: (up: Bool, down: Bool, left: Bool, right: Bool) {
        guard let vector = offset(of: touch) else { return (false, false, false, false) }
        let major = max(abs(vector.dx), abs(vector.dy))
        let leans = { (component: CGFloat) in major > 0 && abs(component) >= major * DishSize.dpadDiagonal }
        return (
            leans(vector.dy) && vector.dy < 0,
            leans(vector.dy) && vector.dy > 0,
            leans(vector.dx) && vector.dx < 0,
            leans(vector.dx) && vector.dx > 0
        )
    }
}
