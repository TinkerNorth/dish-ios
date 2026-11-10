// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What the Moonlight hosts page's rows do: each one an intent, or a link
/// out of Dish.
struct MoonlightHostsActions {
    let scan: @MainActor () -> Void
    /// False when nothing was typed.
    let add: @MainActor (String) -> Bool
    let perform: @MainActor (MoonlightRowAction, String) -> Void
    let pickApp: @MainActor (String, String) -> Void
    let forget: @MainActor (String) -> Void
    let cancelPairing: @MainActor (String) -> Void
    let newCode: @MainActor (String) -> Void
    let quitApp: @MainActor (String) -> Void
    let open: @MainActor (URL?) -> Void
}

/// Moonlight hosts, pushed from Connections: the GameStream hosts (Sunshine,
/// Apollo, Wolf) apart from the satellites, because they pair the other way
/// round. A row carries a trust word, never a liveness light; the PIN the
/// dish mints shows in the row that asked for it; a host mDNS misses is
/// added by address under the rows. Forget asks first.
struct MoonlightHostsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var draft = ""

    var body: some View {
        MoonlightHostsPageBody(state: moonlightHostsPageState(model.moonlightFacts, draft: draft), draft: $draft, actions: actions)
            .onAppear { model.pageAppeared(.moonlightHosts) }
            .onDisappear { model.pageDisappeared(.moonlightHosts) }
    }

    private var actions: MoonlightHostsActions {
        MoonlightHostsActions(
            scan: model.scanMoonlightHosts,
            add: model.addMoonlightHost,
            perform: model.performMoonlight,
            pickApp: model.pickMoonlightApp,
            forget: model.forgetMoonlightHost,
            cancelPairing: model.cancelMoonlightPairing,
            newCode: model.newMoonlightCode,
            quitApp: model.quitMoonlightApp,
            open: open
        )
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }
}

/// The page over its state, so a preview can draw every content state.
struct MoonlightHostsPageBody: View {
    let state: MoonlightHostsPageState
    @Binding var draft: String
    let actions: MoonlightHostsActions

    var body: some View {
        List {
            if let notice = state.notice {
                MoonlightNoticeSection(state: notice, quit: actions.quitApp)
            }
            MoonlightHostsSection(state: state.hosts, actions: actions)
            AddHostSection(state: state.add, draft: $draft, add: submit)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(state.scan, action: actions.scan)
            }
        }
    }

    private func submit() {
        if actions.add(draft) { draft = "" }
    }
}

/// A host's last word, above the rows.
private struct MoonlightNoticeSection: View {
    let state: MoonlightNoticeState
    let quit: @MainActor (String) -> Void

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: DishSpace.s6) {
                RowGlyph(symbol: state.symbol, tint: state.tint)
                VStack(alignment: .leading, spacing: DishSpace.s2) {
                    Text(state.title).font(DishFont.headline).foregroundStyle(DishTheme.onSurface)
                    if let body = state.body {
                        Text(body).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                    }
                    if let action = state.quit {
                        Button(action.title) { quit(action.hostId) }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .font(DishFont.detail)
                    }
                }
            }
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// FOUND ON <network>: the hosts, or the sweep's empty states with their ways forward.
private struct MoonlightHostsSection: View {
    let state: MoonlightHostsSectionState
    let actions: MoonlightHostsActions

    var body: some View {
        Section {
            switch state.list {
            case let .looking(title, body):
                ContentUnavailableView(title, systemImage: DishSymbol.pc, description: Text(body))
            case let .nothing(nothing):
                NothingFoundView(state: nothing, open: actions.open)
            case let .rows(rows):
                ForEach(rows) { MoonlightHostRow(state: $0, actions: actions) }
            }
        } header: {
            MoonlightHostsHeader(title: state.title, searching: state.searching)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// No host answered: where to get Sunshine; the form below takes an address.
private struct NothingFoundView: View {
    let state: MoonlightNothingFoundState
    let open: @MainActor (URL?) -> Void

    var body: some View {
        ContentUnavailableView {
            Label(state.title, systemImage: DishSymbol.pc)
        } description: {
            Text(state.body)
        } actions: {
            Button {
                open(state.getSunshine.url)
            } label: {
                HStack(spacing: DishSpace.s2) {
                    Text(state.getSunshine.title)
                    Image(systemName: DishSymbol.external)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }
}

/// The form that adds a host mDNS does not reach: the address, and Add.
private struct AddHostSection: View {
    let state: MoonlightAddHostState
    @Binding var draft: String
    let add: @MainActor () -> Void

    var body: some View {
        Section {
            TextField(state.placeholder, text: $draft)
                .font(DishFont.mono)
                .foregroundStyle(DishTheme.onSurface)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit(add)
            Button(state.add, action: add)
                .font(DishFont.body)
                .disabled(!state.canAdd)
        } header: {
            SectionEyebrow(title: state.heading, color: DishTheme.muted)
        } footer: {
            Text(state.message).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }
}

private let previewActions = MoonlightHostsActions(
    scan: {},
    add: { _ in false },
    perform: { _, _ in },
    pickApp: { _, _ in },
    forget: { _ in },
    cancelPairing: { _ in },
    newCode: { _ in },
    quitApp: { _ in },
    open: { _ in }
)

#Preview("Moonlight hosts") {
    let pc = MoonlightHost(name: "Den PC", address: "192.168.1.40", uniqueId: "abc")
    let facts = MoonlightFacts(
        hosts: [ConnectionSummary(id: pc.id, name: pc.name, address: pc.address, live: .ready, kind: .moonlight, boundSlotIds: ["pad"])],
        discovered: [MoonlightHost(name: "Attic PC", address: "192.168.1.41")],
        scanning: true,
        phases: [pc.id: .failed(.appAlreadyRunning)],
        apps: [pc.id: [MoonlightApp(id: "1", title: "Desktop", hdrSupported: false)]],
        pin: MoonlightPinPrompt(host: pc, pin: "0451"),
        lastEvent: .appAlreadyRunning(host: pc, resumable: false)
    )
    NavigationStack {
        MoonlightHostsPageBody(state: moonlightHostsPageState(facts, draft: ""), draft: .constant(""), actions: previewActions)
    }
}

#Preview("Nothing found") {
    NavigationStack {
        MoonlightHostsPageBody(state: moonlightHostsPageState(MoonlightFacts(), draft: ""), draft: .constant(""), actions: previewActions)
    }
}
