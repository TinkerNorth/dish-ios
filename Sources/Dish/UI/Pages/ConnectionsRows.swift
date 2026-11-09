// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// One PC: its glyph, its name in mono, and its state under a dot.
struct ConnectionRow: View {
    let state: ConnectionRowState

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            RowGlyph(symbol: state.symbol)
            VStack(alignment: .leading, spacing: DishSpace.s1) {
                Text(state.name).font(DishFont.mono).bold().foregroundStyle(DishTheme.onSurface)
                HStack(spacing: DishSpace.s3) {
                    StatusDot(color: state.dot)
                    Text(state.line).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                }
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// FOUND ON <network>, with the spinner while discovery looks.
struct FoundHeader: View {
    let state: FoundSectionState

    var body: some View {
        HStack(spacing: DishSpace.s3) {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
            Spacer()
            if let searching = state.searching {
                ProgressView()
                Text(searching).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
    }
}

/// Moonlight hosts: Sunshine, Apollo or Wolf. Not tappable yet.
struct MoonlightHostsRow: View {
    let title: String
    let hint: String

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            RowGlyph(symbol: connectionSymbol(.moonlight))
            VStack(alignment: .leading, spacing: DishSpace.s1) {
                Text(title).font(DishFont.body).foregroundStyle(DishTheme.onSurface)
                Text(hint).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// D3: Local Network is off. Open Settings goes to Dish's page in the
/// Settings app, and the caption says where the switch is.
struct NetworkDeniedView: View {
    let state: NetworkDeniedState

    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label(state.title, systemImage: "wifi.slash")
        } description: {
            Text(state.body)
        } actions: {
            if let url = state.settingsURL {
                Button(state.openSettings) { openURL(url) }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            }
            Text(state.caption).font(DishFont.monoDetail).foregroundStyle(DishTheme.muted)
        }
    }
}
