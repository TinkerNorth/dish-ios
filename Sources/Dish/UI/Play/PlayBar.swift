// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What a play screen's controls and its way out do: each one an intent.
struct PlayActions {
    let pad: @MainActor (OnScreenPadEvent) -> Void
    let touch: @MainActor (TouchSurfaceEvent) -> Void
    /// A tap on the gamepad's touchpad: its click.
    let tap: @MainActor () -> Void
    let stop: @MainActor () -> Void
}

/// C3: the way out of every play screen, a back chevron beside the PC pill.
/// It closes the screen and keeps the on-screen controller's binding.
struct PlayBackButton: View {
    let title: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: DishSymbol.back)
                .font(DishFont.headline)
                .foregroundStyle(DishTheme.onSurface)
                .frame(width: DishSize.padRound, height: DishSize.padRound)
                .background(Circle().fill(DishTheme.surface))
                .overlay(Circle().stroke(DishTheme.outline, lineWidth: DishSize.padStroke))
        }
        .buttonStyle(.round)
        .accessibilityLabel(Text(title))
    }
}

/// A play screen's name at the top bar's leading edge, its glyph before it.
struct PlayEyebrow: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: DishSpace.s4) {
            Image(systemName: symbol).font(DishFont.headline).foregroundStyle(DishTheme.primary)
            SectionEyebrow(title: title, color: DishTheme.primary)
        }
        .accessibilityElement(children: .combine)
    }
}
