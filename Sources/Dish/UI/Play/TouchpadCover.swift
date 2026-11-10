// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The touchpad: a plain surface for one or two fingers, and its two click
/// zones under it, as Android's touchpad screen has them.
struct TouchpadCover: View {
    let state: PlayCoverState
    let actions: PlayActions

    private var words: TouchpadCoverState {
        state.touchpad
    }

    var body: some View {
        VStack(spacing: DishSpace.s8) {
            PlayTopBar(state: state, actions: actions) {
                SectionEyebrow(title: words.eyebrow, color: DishTheme.primary)
            } trailing: {
                EmptyView()
            }
            TwoFingerSurface(hint: words.hint) { actions.touch(fingerMove($0, $1)) }
            HStack(spacing: DishSpace.s8) {
                HoldPanel(title: words.click) { actions.touch(.clickZone(.left, held: $0)) }
                HoldPanel(title: words.click) { actions.touch(.clickZone(.right, held: $0)) }
            }
            .frame(height: state.pad.metrics.clickZone)
        }
        .padding(.vertical, DishSpace.s6)
    }
}

#Preview("Touchpad", traits: .landscapeLeft) {
    let state = playCoverState(facts: FactsPreview.playing(.touchpad), screen: .touchpad, window: PreviewWindow.phoneOnItsSide)
    TouchpadCover(state: state, actions: .preview)
        .padding(.horizontal, DishSpace.page)
        .background(DishTheme.background)
        .environment(\.colorScheme, .dark)
}

#Preview("Touchpad, iPad on its side", traits: .landscapeLeft) {
    let state = playCoverState(facts: FactsPreview.playing(.touchpad), screen: .touchpad, window: PreviewWindow.iPadOnItsSide)
    PlayCoverBody(state: state, actions: .preview)
        .environment(\.colorScheme, .dark)
}
