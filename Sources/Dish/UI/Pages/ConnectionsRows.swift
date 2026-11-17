// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// One PC: its glyph, its name in mono, and its state under a dot. A paired
/// row opens its PC's page, pushed with a chevron from a stack, selected
/// beside a split's list; a row with a button pairs or connects. A long
/// press and a swipe offer the row's actions; Forget This PC asks first.
struct ConnectionRow: View {
    let state: ConnectionRowState
    var layout = TabLayout.stack
    /// The page a split's detail shows, which marks its row.
    var selection: Page?
    let open: @MainActor (Page) -> Void
    let act: @MainActor (ConnectionRowAction) -> Void

    @State private var forgetAsked = false

    var body: some View {
        switch rowOpening(state.page, layout: layout, selection: selection) {
        case let .push(page):
            RowButton {
                open(page)
            } label: {
                ConnectionRowContent(state: state, disclosure: true)
            } trailing: {
                sideButton
            }
            .modifier(RowActions(state: state.actions, perform: perform))
            .modifier(ForgetDialog(state: state.forget, isPresented: $forgetAsked, forget: forget))
        case let .select(page, selected):
            line { ConnectionRowContent(state: state, disclosure: false) }
                .tag(page)
                .selectedRow(selected)
        case .inert:
            line { ConnectionRowContent(state: state, disclosure: false) }
        }
    }

    /// The row's content, then its Pair or Connect.
    private func line(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: DishSpace.s6) {
            content()
            sideButton
        }
        .modifier(RowActions(state: state.actions, perform: perform))
        .modifier(ForgetDialog(state: state.forget, isPresented: $forgetAsked, forget: forget))
    }

    /// Pair or Connect, when the row's state calls for one.
    @ViewBuilder private var sideButton: some View {
        if let button = state.button {
            Button(button.title) { act(button.action) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .font(DishFont.headline)
        }
    }

    /// Forget This PC asks first; every other action is the page's at once.
    private func perform(_ action: ConnectionRowAction) {
        switch action {
        case .forget: forgetAsked = true
        case .pair, .connect, .reconnect, .cancel, .disconnect: act(action)
        }
    }

    private func forget() {
        act(.forget(id: state.id))
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
                Text(state.name).font(DishFont.mono).bold().foregroundStyle(DishTheme.onSurface).lineLimit(1)
                HStack(spacing: DishSpace.s3) {
                    StatusMarkView(mark: state.mark)
                    Text(state.line).font(DishFont.detail).foregroundStyle(state.lineColor).lineLimit(2)
                }
            }
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

/// Moonlight hosts: Sunshine, Apollo or Wolf. A tap opens their page,
/// pushed with a chevron from a stack, selected beside a split's list.
struct MoonlightHostsRow: View {
    let title: String
    let hint: String
    var layout = TabLayout.stack
    /// The page a split's detail shows, which marks its row.
    var selection: Page?
    let open: @MainActor (Page) -> Void

    var body: some View {
        switch rowOpening(.moonlightHosts, layout: layout, selection: selection) {
        case let .push(page):
            RowButton {
                open(page)
            } label: {
                content(disclosure: true)
            }
        case let .select(page, selected):
            content(disclosure: false)
                .tag(page)
                .selectedRow(selected)
        case .inert:
            content(disclosure: false)
        }
    }

    private func content(disclosure: Bool) -> some View {
        HStack(spacing: DishSpace.s6) {
            RowGlyph(symbol: connectionSymbol(.moonlight))
            VStack(alignment: .leading, spacing: DishSpace.s1) {
                Text(title).font(DishFont.body).foregroundStyle(DishTheme.onSurface)
                Text(hint).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
            Spacer(minLength: DishSpace.s4)
            if disclosure {
                Image(systemName: DishSymbol.disclosure).font(DishFont.detail).foregroundStyle(DishTheme.muted)
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
