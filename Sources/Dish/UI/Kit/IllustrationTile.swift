// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// A tile of an illustration: an SF Symbol in the accent on its fill, with
/// its eyebrow under it. The Local Network primer's phone and PC, and the
/// adapter sheet's phone and controller.
struct IllustrationTile: View {
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
    HStack(spacing: DishSpace.s12) {
        IllustrationTile(symbol: "iphone", label: "This iPhone")
        IllustrationTile(symbol: "desktopcomputer", label: "Your PC")
    }
    .padding()
    .background(DishTheme.background)
}
