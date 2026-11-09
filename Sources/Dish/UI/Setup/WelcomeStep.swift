// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// B1: what Dish is, the three things it does, Continue, and the Satellite
/// download for a PC that has none yet.
struct WelcomeStep: View {
    let state: WelcomeStepState

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: DishSpace.s12) {
                DishImage.mark
                    .resizable()
                    .scaledToFit()
                    .frame(width: DishSize.welcomeMark, height: DishSize.welcomeMark)
                    .accessibilityHidden(true)
                VStack(spacing: DishSpace.s6) {
                    Text(state.headline)
                        .font(DishFont.largeTitle)
                        .foregroundStyle(DishTheme.onSurface)
                    Text(state.intro)
                        .font(DishFont.body)
                        .foregroundStyle(DishTheme.muted)
                }
                .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: DishSpace.s12) {
                    ForEach(state.features) { feature in
                        WelcomeFeatureRow(feature: feature)
                    }
                }
            }
            .padding(.horizontal, DishSpace.page)
            .padding(.vertical, DishSpace.s8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            SetupBottomBar(title: state.primary, action: model.setupNext) {
                Button(state.getSatellite.title, action: openSatellite)
                    .font(DishFont.body)
                    .tint(DishTheme.primary)
            }
        }
    }

    private func openSatellite() {
        guard let url = state.getSatellite.url else { return }
        openURL(url)
    }
}

private struct WelcomeFeatureRow: View {
    let feature: SetupFeature

    var body: some View {
        HStack(alignment: .top, spacing: DishSpace.s8) {
            Image(systemName: feature.symbol)
                .font(DishFont.feature)
                .foregroundStyle(DishTheme.primary)
                .frame(width: DishSize.featureSymbol)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DishSpace.s2) {
                Text(feature.title)
                    .font(DishFont.headline)
                    .foregroundStyle(DishTheme.onSurface)
                Text(feature.body)
                    .font(DishFont.detail)
                    .foregroundStyle(DishTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeStep(state: welcomeStepState())
        .environment(AppModel())
        .background(DishTheme.background)
}
