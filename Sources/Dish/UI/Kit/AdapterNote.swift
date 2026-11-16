// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// The Lightning note as a row: the bolt on its warning tile, the port
/// named, why a plain cable will not do, and the way to the sheet that says
/// what will. The whole row opens it.
struct AdapterNoteRow: View {
    let state: AdapterNoteState
    let more: () -> Void

    var body: some View {
        Button(action: more) {
            HStack(alignment: .top, spacing: DishSpace.s6) {
                RowGlyph(symbol: state.symbol, tint: DishTheme.warning, fill: DishTheme.warningFill)
                VStack(alignment: .leading, spacing: DishSpace.s1) {
                    Text(state.title)
                        .font(DishFont.body)
                        .foregroundStyle(DishTheme.onSurface)
                    Text(state.body)
                        .font(DishFont.detail)
                        .foregroundStyle(DishTheme.muted)
                    Text(state.more)
                        .font(DishFont.detail)
                        .foregroundStyle(DishTheme.primary)
                        .padding(.top, DishSpace.s2)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DishSpace.s4)
                Image(systemName: DishSymbol.disclosure)
                    .font(DishFont.detail)
                    .foregroundStyle(DishTheme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let note = AdapterNoteState(
        symbol: "bolt.fill",
        title: "Lightning port",
        body: "A wired controller needs an adapter.",
        more: "What you need"
    )
    List {
        AdapterNoteRow(state: note, more: {})
    }
}
