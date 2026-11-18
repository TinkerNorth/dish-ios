// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// A control held over the kit's touch surface in its shape, from the first
/// finger's landing to the last one's lift.
private struct HoldTracking<Hit: Shape>: ViewModifier {
    let shape: Hit
    let onChange: (Bool) -> Void

    @State private var held = false

    func body(content: Content) -> some View {
        content.onFingers(shape) { fingers, _ in hold(holding(fingers)) }
    }

    private func hold(_ isHeld: Bool) {
        guard isHeld != held else { return }
        held = isHeld
        onChange(isHeld)
    }
}

extension View {
    /// Reports a finger landing on this view within `shape` (true) and the
    /// last finger lifting (false).
    func onHold(_ shape: some Shape, _ onChange: @escaping (Bool) -> Void) -> some View {
        modifier(HoldTracking(shape: shape, onChange: onChange))
    }
}

/// A face button: a ring in the button's colour with its letter or glyph,
/// filled while held, as wide as the page hands it.
struct FaceButton: View {
    let state: FaceButtonState
    let size: CGFloat
    let onChange: (Bool) -> Void

    @State private var held = false

    var body: some View {
        ZStack {
            Circle()
                .fill(held ? state.tint : DishTheme.surfaceDim)
                .shadow(color: held ? DishTheme.padGlow : Color.clear, radius: DishSize.padGlow)
            Circle().stroke(state.tint, lineWidth: DishSize.padHeldStroke)
            glyph.foregroundStyle(held ? DishTheme.onPrimary : state.tint)
        }
        .frame(width: size, height: size)
        .onHold(Circle(), hold)
    }

    @ViewBuilder private var glyph: some View {
        switch state.glyph {
        case let .letter(letter): Text(letter).font(DishFont.padFace)
        case let .symbol(name): Image(systemName: name).font(DishFont.padFace)
        }
    }

    private func hold(_ isHeld: Bool) {
        held = isHeld
        onChange(isHeld)
    }
}

/// What a round control shows: a short label or a symbol.
enum RoundPadFace: Equatable {
    case label(String)
    case symbol(String)
}

/// A small round control: L3, R3 and the centre's View, Guide and Menu.
struct RoundPadButton: View {
    let face: RoundPadFace
    let onChange: (Bool) -> Void

    @State private var held = false

    var body: some View {
        ZStack {
            Circle().fill(held ? DishTheme.primaryFill : DishTheme.surfaceDim)
            Circle().stroke(held ? DishTheme.primary : DishTheme.outline, lineWidth: DishSize.padStroke)
            content.foregroundStyle(held ? DishTheme.primary : DishTheme.muted)
        }
        .frame(width: DishSize.padRound, height: DishSize.padRound)
        .onHold(Circle(), hold)
    }

    @ViewBuilder private var content: some View {
        switch face {
        case let .label(text): Text(text).font(DishFont.padSmall)
        case let .symbol(name): Image(systemName: name).font(DishFont.headline)
        }
    }

    private func hold(_ isHeld: Bool) {
        held = isHeld
        onChange(isHeld)
    }
}

/// A shoulder button along the top edge: a capsule with its name.
struct ShoulderButton: View {
    let title: String
    let onChange: (Bool) -> Void

    @State private var held = false

    var body: some View {
        Text(title)
            .font(DishFont.padLabel)
            .foregroundStyle(held ? DishTheme.primary : DishTheme.onSurface)
            .frame(width: DishSize.padShoulderWidth, height: DishSize.padShoulderHeight)
            .background(Capsule().fill(held ? DishTheme.primaryFill : DishTheme.surfaceDim))
            .overlay(Capsule().stroke(held ? DishTheme.primary : DishTheme.outline, lineWidth: DishSize.padStroke))
            .onHold(Capsule(), hold)
    }

    private func hold(_ isHeld: Bool) {
        held = isHeld
        onChange(isHeld)
    }
}

/// A large rounded panel held like a button: the mouse's Left and Right,
/// and the touchpad's click zones.
struct HoldPanel: View {
    let title: String
    let onChange: (Bool) -> Void

    @State private var held = false

    var body: some View {
        RoundedRectangle(cornerRadius: DishSize.mouseCorner)
            .fill(held ? DishTheme.primaryFill : DishTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: DishSize.mouseCorner).stroke(
                held ? DishTheme.primary : DishTheme.outline,
                lineWidth: DishSize.padStroke
            ))
            .overlay(Text(title).font(DishFont.headline).foregroundStyle(DishTheme.onSurface))
            .onHold(RoundedRectangle(cornerRadius: DishSize.mouseCorner), hold)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }

    private func hold(_ isHeld: Bool) {
        held = isHeld
        onChange(isHeld)
    }
}
