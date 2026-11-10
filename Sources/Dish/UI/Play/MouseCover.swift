// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// C4, the mouse: Left, the Scroll strip and Right down the left, the move
/// pad filling the rest. The pad reports touches and clicks; the pointer's
/// shape on the wire is the sender's business.
struct MouseCover: View {
    let state: PlayCoverState
    let actions: PlayActions

    private var words: MouseCoverState {
        state.mouse
    }

    var body: some View {
        VStack(spacing: DishSpace.s8) {
            PlayTopBar(state: state, actions: actions) {
                SectionEyebrow(title: words.eyebrow, color: DishTheme.primary)
            } trailing: {
                EmptyView()
            }
            HStack(spacing: DishSpace.s12) {
                VStack(spacing: DishSpace.s8) {
                    HoldPanel(title: words.left) { actions.touch(.leftButton(held: $0)) }
                    ScrollStrip(title: words.scroll, upSymbol: PlaySymbol.scrollUp, downSymbol: PlaySymbol.scrollDown) {
                        actions.touch(.scroll(points: Float($0)))
                    }
                    HoldPanel(title: words.right) { actions.touch(.rightButton(held: $0)) }
                }
                .frame(width: DishSize.mouseColumn)
                MovePad(hint: words.hint) { actions.touch(fingerMove(0, $0)) }
            }
        }
        .padding(.vertical, DishSpace.s6)
    }
}

#Preview("Mouse", traits: .landscapeLeft) {
    MouseCover(
        state: playCoverState(facts: FactsPreview.playing(.mouse), screen: .mouse, window: PreviewWindow.phoneOnItsSide),
        actions: .preview
    )
    .padding(.horizontal, DishSpace.page)
    .background(DishTheme.background)
    .environment(\.colorScheme, .dark)
}

#Preview("Mouse, iPad on its side", traits: .landscapeLeft) {
    let state = playCoverState(facts: FactsPreview.playing(.mouse), screen: .mouse, window: PreviewWindow.iPadOnItsSide)
    PlayCoverBody(state: state, actions: .preview)
        .environment(\.colorScheme, .dark)
}
