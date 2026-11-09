// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// A setup page's question and the line under it, at the head of its list.
struct SetupHeading: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s3) {
            Text(title)
                .font(DishFont.largeTitle)
                .foregroundStyle(DishTheme.onSurface)
            Text(detail)
                .font(DishFont.body)
                .foregroundStyle(DishTheme.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: DishSpace.s4, leading: DishSpace.s2, bottom: DishSpace.s4, trailing: DishSpace.s2))
    }
}

/// The accent glyph tile at the head of a setup row.
struct SetupGlyphTile: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(DishFont.headline)
            .foregroundStyle(DishTheme.primary)
            .frame(width: DishSize.rowGlyph, height: DishSize.rowGlyph)
            .background(DishTheme.primaryFill, in: RoundedRectangle(cornerRadius: DishSize.rowGlyphCorner))
    }
}

/// A row's title and the line under it.
struct SetupRowText: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s1) {
            Text(title)
                .font(DishFont.body)
                .foregroundStyle(DishTheme.onSurface)
            Text(detail)
                .font(DishFont.detail)
                .foregroundStyle(DishTheme.muted)
        }
    }
}

/// The page's one way on, pinned to the bottom: a prominent full-width
/// button, with a quieter link under it when the page has one.
struct SetupBottomBar<Secondary: View>: View {
    let title: String
    let action: () -> Void
    @ViewBuilder let secondary: () -> Secondary

    var body: some View {
        VStack(spacing: DishSpace.s6) {
            Button(action: action) {
                Text(title)
                    .font(DishFont.headline)
                    .foregroundStyle(DishTheme.onPrimary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(DishTheme.primary)
            .controlSize(.large)
            secondary()
        }
        .padding(.horizontal, DishSpace.page)
        .padding(.bottom, DishSpace.s4)
    }
}

extension SetupBottomBar where Secondary == EmptyView {
    init(title: String, action: @escaping () -> Void) {
        self.init(title: title, action: action) { EmptyView() }
    }
}
