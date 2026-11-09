// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// The Connections tab (D1, D3): paired PCs, the ones found on the network,
/// Moonlight hosts; or, with Local Network off, the way to turn it on.
struct ConnectionsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.settingsURL) private var settingsURL

    var body: some View {
        ConnectionsPageBody(title: tabTitle(.connections), state: connectionsPageState(facts: model.shellFacts, settingsURL: settingsURL))
            .onAppear { model.pageAppeared(.connections) }
            .onDisappear { model.pageDisappeared(.connections) }
    }
}

/// The page over its state, so a preview can draw every content state.
struct ConnectionsPageBody: View {
    let title: String
    let state: ConnectionsPageState

    var body: some View {
        content
            .background(DishTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder private var content: some View {
        switch state {
        case let .denied(denied): NetworkDeniedView(state: denied)
        case let .empty(title, body): ContentUnavailableView(title, systemImage: satelliteSymbol, description: Text(body))
        case let .list(list): ConnectionsList(state: list)
        }
    }
}

/// PAIRED, FOUND ON, Moonlight hosts and the footnote.
private struct ConnectionsList: View {
    let state: ConnectionsListState

    var body: some View {
        List {
            if let paired = state.paired {
                Section {
                    ForEach(paired.rows) { ConnectionRow(state: $0) }
                } header: {
                    SectionEyebrow(title: paired.title, color: DishTheme.muted)
                }
                .listRowBackground(DishTheme.surface)
            }
            if let found = state.found {
                Section {
                    ForEach(found.rows) { ConnectionRow(state: $0) }
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
        ConnectionsPageBody(title: tabTitle(.connections), state: connectionsPageState(facts: facts, settingsURL: nil))
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
            title: tabTitle(.connections),
            state: connectionsPageState(facts: facts, settingsURL: URL(string: "app-settings:"))
        )
    }
}
