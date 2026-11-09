// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// The rounded tile at the head of a row: an SF Symbol in the brand glyph
/// colour on the dim surface, or in another pair for a warning.
struct RowGlyph: View {
    let symbol: String
    var tint = DishTheme.brandGlyph
    var fill = DishTheme.surfaceDim

    var body: some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .frame(width: DishSize.rowGlyphSymbol, height: DishSize.rowGlyphSymbol)
            .foregroundStyle(tint)
            .frame(width: DishSize.rowGlyph, height: DishSize.rowGlyph)
            .background(RoundedRectangle(cornerRadius: DishSize.rowGlyphCorner, style: .continuous).fill(fill))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        RowGlyph(symbol: "gamecontroller")
        RowGlyph(symbol: "iphone")
        RowGlyph(symbol: "exclamationmark.triangle.fill", tint: DishTheme.error, fill: DishTheme.errorDim)
    }
    .padding()
    .background(DishTheme.background)
}
