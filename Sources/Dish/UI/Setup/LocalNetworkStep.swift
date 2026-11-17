// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// B3, Destination · 2 of 3: why iOS is about to ask, before it does.
/// Continue lets iOS put its question; a PC can be added by address
/// instead, which opens its sheet.
struct LocalNetworkStep: View {
    let state: LocalNetworkStepState

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        List {
            PrimerIllustration(thisIPhone: state.thisIPhone, yourPC: state.yourPC)
            SetupHeading(title: state.title, detail: state.body)
            Section {
                ForEach(state.rows) { row in
                    HStack(spacing: DishSpace.s6) {
                        SetupGlyphTile(symbol: row.symbol)
                        SetupRowText(title: row.title, detail: row.body)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .listRowBackground(DishTheme.surface)
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            SetupBottomBar(title: state.primary, action: model.setupNext) {
                Button(state.byAddress, action: addByAddress)
                    .font(DishFont.body)
                    .tint(DishTheme.primary)
            }
        }
    }

    private func addByAddress() {
        model.pickSetupDestination(.byAddress)
        navigation.send(.openSheet(.addByAddress))
    }
}

/// The phone and the PC with the Wi‑Fi between them.
private struct PrimerIllustration: View {
    let thisIPhone: String
    let yourPC: String

    var body: some View {
        HStack(spacing: DishSpace.s12) {
            IllustrationTile(symbol: DishSymbol.phone, label: thisIPhone)
            Image(systemName: DishSymbol.wifi)
                .font(DishFont.feature)
                .foregroundStyle(DishTheme.primary)
            IllustrationTile(symbol: DishSymbol.pc, label: yourPC)
        }
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityHidden(true)
    }
}

#Preview {
    LocalNetworkStep(state: localNetworkStepState())
        .environment(PreviewSetup.emptyModel())
        .environment(PreviewSetup.navigation())
}
