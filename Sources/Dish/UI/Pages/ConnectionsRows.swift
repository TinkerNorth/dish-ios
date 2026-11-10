// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// One PC: its glyph, its name in mono, and its state under a dot. A paired
/// row opens its PC's page; a row with a button pairs or connects.
struct ConnectionRow: View {
    let state: ConnectionRowState
    let open: @MainActor (Page) -> Void
    let act: @MainActor (ConnectionRowAction) -> Void

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            if let page = state.page {
                Button {
                    open(page)
                } label: {
                    ConnectionRowContent(state: state, disclosure: true)
                }
                .buttonStyle(.borderless)
            } else {
                ConnectionRowContent(state: state, disclosure: false)
            }
            if let button = state.button {
                Button(button.title) { act(button.action) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .font(DishFont.headline)
            }
        }
    }
}

/// The row's own layout.
private struct ConnectionRowContent: View {
    let state: ConnectionRowState
    let disclosure: Bool

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
            Spacer(minLength: DishSpace.s4)
            if disclosure {
                Image(systemName: DishSymbol.disclosure).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
        .contentShape(Rectangle())
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

/// Moonlight hosts: Sunshine, Apollo or Wolf. A tap pushes their page.
struct MoonlightHostsRow: View {
    let title: String
    let hint: String

    var body: some View {
        NavigationLink(value: Page.moonlightHosts) {
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
