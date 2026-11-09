// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// B3, Destination · 2 of 3: why iOS is about to ask, before it does.
/// Continue lets iOS put its question; a PC can be added by address instead.
struct LocalNetworkStep: View {
    let state: LocalNetworkStepState

    @Environment(AppModel.self) private var model

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
    }
}

/// The phone and the PC with the Wi‑Fi between them.
private struct PrimerIllustration: View {
    let thisIPhone: String
    let yourPC: String

    var body: some View {
        HStack(spacing: DishSpace.s12) {
            PrimerTile(symbol: DishSymbol.phone, label: thisIPhone)
            Image(systemName: DishSymbol.wifi)
                .font(DishFont.feature)
                .foregroundStyle(DishTheme.primary)
            PrimerTile(symbol: DishSymbol.pc, label: yourPC)
        }
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityHidden(true)
    }
}

private struct PrimerTile: View {
    let symbol: String
    let label: String

    var body: some View {
        VStack(spacing: DishSpace.s4) {
            Image(systemName: symbol)
                .font(DishFont.feature)
                .foregroundStyle(DishTheme.primary)
                .frame(width: DishSize.primerTile, height: DishSize.primerTile)
                .background(DishTheme.primaryFill, in: RoundedRectangle(cornerRadius: DishSize.rowGlyphCorner))
            SectionEyebrow(title: label, color: DishTheme.muted)
        }
    }
}

#Preview {
    LocalNetworkStep(state: localNetworkStepState())
        .environment(AppModel())
}
