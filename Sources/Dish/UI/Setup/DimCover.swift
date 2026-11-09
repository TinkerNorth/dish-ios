// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// C5, the low-power dim: true black with the system's overlays hidden, so
/// the panel draws almost nothing while a pad streams. The clock, the
/// session card and the words; a tap anywhere wakes, and streaming goes on.
struct DimCover: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        DimCoverBody(state: dimCoverState(facts: model.shellFacts), wake: wake)
            .onAppear { model.pageAppeared(.dim) }
            .onDisappear { model.pageDisappeared(.dim) }
    }

    private func wake() {
        navigation.send(.wake)
    }
}

/// The dim over its state, so a preview can draw it with and without a session.
struct DimCoverBody: View {
    let state: DimCoverState
    let wake: () -> Void

    var body: some View {
        ZStack {
            DishTheme.dimBackground
                .ignoresSafeArea()
                .onTapGesture(perform: wake)
            VStack(spacing: DishSpace.s6) {
                Spacer()
                SectionEyebrow(title: state.eyebrow, color: DishTheme.primaryDark)
                Text(state.clock)
                    .font(DishFont.dimClock)
                    .monospacedDigit()
                    .foregroundStyle(DishTheme.dimText)
                if let card = state.card {
                    DimSessionCard(state: card)
                        .padding(.top, DishSpace.s12)
                }
                Spacer()
                SectionEyebrow(title: state.wake, color: DishTheme.dimText)
                Text(state.footnote)
                    .font(DishFont.detail)
                    .foregroundStyle(DishTheme.dimText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DishSpace.page)
            .padding(.bottom, DishSpace.s8)
            .allowsHitTesting(false)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.wake)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, wake)
    }
}

/// The PC streaming on, its session line, and each bound pad's level.
private struct DimSessionCard: View {
    let state: DimCardState

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s4) {
            HStack(spacing: DishSpace.s4) {
                StatusDot(color: state.dot)
                Text(state.pcName).font(DishFont.mono).foregroundStyle(DishTheme.dimText)
            }
            Text(state.line).font(DishFont.monoDetail).foregroundStyle(state.lineColor)
            if !state.pads.isEmpty {
                Divider().overlay(DishTheme.cardStroke)
                ForEach(state.pads) { pad in
                    HStack {
                        Text(pad.name)
                        Spacer()
                        Text(pad.battery).monospacedDigit()
                    }
                    .font(DishFont.monoDetail)
                    .foregroundStyle(DishTheme.dimText)
                }
            }
        }
        .padding(DishSpace.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DishSize.dimCardCorner).fill(DishTheme.dimCard))
        .overlay(RoundedRectangle(cornerRadius: DishSize.dimCardCorner).stroke(DishTheme.cardStroke, lineWidth: DishSize.padStroke))
    }
}

#Preview("Streaming") {
    DimCoverBody(state: dimCoverState(facts: FactsPreview.facts()), wake: {})
}

#Preview("No session") {
    DimCoverBody(state: dimCoverState(facts: FactsPreview.facts(session: nil)), wake: {})
}
