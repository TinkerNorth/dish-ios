// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// C5, the low-power dim: true black with the system's overlays hidden, so
/// the panel draws almost nothing while a pad streams. A tap anywhere wakes.
struct DimCover: View {
    @Environment(NavigationStore.self) private var navigation

    private let words = L10n.app

    var body: some View {
        ZStack {
            DishTheme.dimBackground
                .ignoresSafeArea()
                .onTapGesture(perform: wake)
            VStack(spacing: DishSpace.s6) {
                Spacer()
                SectionEyebrow(title: words.lowPower, color: DishTheme.primaryDark)
                Spacer()
                SectionEyebrow(title: words.tapToWake, color: DishTheme.dimText)
                Text(words.dimFootnote)
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
        .accessibilityLabel(words.tapToWake)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, wake)
    }

    private func wake() {
        navigation.send(.wake)
    }
}

#Preview {
    DimCover()
        .environment(PreviewSetup.navigation())
}
