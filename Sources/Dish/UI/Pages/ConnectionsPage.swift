// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// What the Connections rows and toolbar do: a paired row opens its PC's
/// page, Pair opens the sheet, Connect reaches for the PC, and the toolbar's
/// plus adds a PC by address.
struct ConnectionsActions {
    let open: @MainActor (Page) -> Void
    let act: @MainActor (ConnectionRowAction) -> Void
    let add: @MainActor () -> Void

    /// Controls that do nothing, for a preview.
    @MainActor static let preview = ConnectionsActions(open: { _ in }, act: { _ in }, add: {})
}

/// The Connections tab (D1, D3): paired PCs, the ones found on the network,
/// Moonlight hosts; or, with Local Network off, the way to turn it on. It
/// looks for PCs as it opens. A paired PC's page is pushed on a phone and
/// shown beside the list on an iPad.
struct ConnectionsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation
    @Environment(\.settingsURL) private var settingsURL
    @Environment(\.windowFacts) private var window

    var body: some View {
        let layout = tabLayout(.connections, width: window.width)
        ConnectionsPageBody(
            state: connectionsPageState(facts: model.shellFacts, settingsURL: settingsURL),
            layout: layout,
            selection: listSelection(navigation.listSelection(of: .connections), layout: layout),
            actions: ConnectionsActions(open: open, act: act, add: addByAddress)
        )
        .onAppear { model.pageAppeared(.connections) }
        .onDisappear { model.pageDisappeared(.connections) }
    }

    /// A paired row's page, alone on the tab.
    private func open(_ page: Page) {
        navigation.send(.show(page, in: .connections))
    }

    private func act(_ action: ConnectionRowAction) {
        switch action {
        case let .pair(serverId): navigation.send(.openSheet(.pair(serverId: serverId)))
        case let .connect(id): model.connect(id)
        }
    }

    private func addByAddress() {
        navigation.send(.openSheet(.addByAddress))
    }
}

/// The page over its state, so a preview can draw every content state. On
/// an iPad the list selects the PC shown beside it.
struct ConnectionsPageBody: View {
    let state: ConnectionsPageState
    var layout = TabLayout.stack
    /// The page beside the list; nil while the list is a stack's.
    var selection: Binding<Page?>?
    let actions: ConnectionsActions

    var body: some View {
        content
            .background(DishTheme.background)
            .navigationTitle(state.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(state.add, systemImage: DishSymbol.add, action: actions.add)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch state.content {
        case let .denied(denied): NetworkDeniedView(state: denied)
        case let .empty(title, body): ContentUnavailableView(title, systemImage: satelliteSymbol, description: Text(body))
        case let .list(list): ConnectionsList(state: list, layout: layout, selection: selection, actions: actions)
        }
    }
}

/// PAIRED, FOUND ON, Moonlight hosts and the footnote.
private struct ConnectionsList: View {
    let state: ConnectionsListState
    let layout: TabLayout
    let selection: Binding<Page?>?
    let actions: ConnectionsActions

    var body: some View {
        List(selection: selection) {
            if let paired = state.paired {
                Section {
                    ForEach(paired.rows) { ConnectionRow(state: $0, layout: layout, open: actions.open, act: actions.act) }
                } header: {
                    SectionEyebrow(title: paired.title, color: DishTheme.muted)
                }
                .listRowBackground(DishTheme.surface)
            }
            if let found = state.found {
                Section {
                    ForEach(found.rows) { ConnectionRow(state: $0, layout: layout, open: actions.open, act: actions.act) }
                } header: {
                    FoundHeader(state: found)
                }
                .listRowBackground(DishTheme.surface)
            }
            Section {
                MoonlightHostsRow(title: state.moonlightTitle, hint: state.moonlightHint)
            } footer: {
                Text(state.footnote).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
            .listRowBackground(DishTheme.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

#Preview("Connections") {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let facts = ShellFacts(
        controllers: [],
        attachedPads: [],
        paired: [
            ConnectionFact(
                id: "1",
                name: "Living Room PC",
                address: "192.168.1.20",
                kind: .satellite,
                state: .online(latencyMs: 4, controllers: 3)
            ),
            ConnectionFact(
                id: "2",
                name: "Office PC",
                address: "192.168.1.30",
                kind: .satellite,
                state: .offline(lastSeen: now.addingTimeInterval(-86400))
            )
        ],
        found: [ConnectionFact(id: "3", name: "Den PC", address: "192.168.1.40", kind: .satellite, state: .needsPairing)],
        scanning: true,
        session: nil,
        localNetwork: .allowed,
        preferences: PreferencesFacts(deviceName: "", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system),
        now: now,
        setup: nil
    )
    NavigationStack {
        ConnectionsPageBody(state: connectionsPageState(facts: facts, settingsURL: nil), actions: .preview)
    }
}

#Preview("Local Network off") {
    let facts = ShellFacts(
        controllers: [],
        attachedPads: [],
        paired: [],
        found: [],
        scanning: false,
        session: nil,
        localNetwork: .denied,
        preferences: PreferencesFacts(deviceName: "", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system),
        now: .distantPast,
        setup: nil
    )
    NavigationStack {
        ConnectionsPageBody(
            state: connectionsPageState(facts: facts, settingsURL: URL(string: "app-settings:")),
            actions: .preview
        )
    }
}
