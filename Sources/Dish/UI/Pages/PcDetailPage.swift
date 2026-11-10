// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// What a PC page's buttons do: Re-pair opens the sheet, Connect and
/// Disconnect move the session, Forget drops the PC and pops the page.
struct PcActions {
    let act: @MainActor (PcAction) -> Void
    let forget: @MainActor () -> Void

    /// Controls that do nothing, for a preview.
    @MainActor static let preview = PcActions(act: { _ in }, forget: {})
}

/// Connections › a paired PC (D2): the status card, what it carries each
/// way, the controllers bound to it, Re-pair, Disconnect or Connect, and
/// Forget This PC, which asks first.
struct PcDetailPage: View {
    let id: String

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        PcDetailPageBody(state: pcDetailPageState(facts: model.shellFacts, id: id), actions: PcActions(act: act, forget: forget))
    }

    private func act(_ action: PcAction) {
        switch action {
        case .repair: navigation.send(.openSheet(.pair(serverId: id)))
        case .connect: model.connect(id)
        case .disconnect: model.disconnect(id)
        }
    }

    /// The page pops before the PC goes, so it never reads gone.
    private func forget() {
        navigation.send(.pop)
        model.forget(id)
    }
}

/// The page over its state, so a preview can draw every state.
struct PcDetailPageBody: View {
    let state: PcDetailPageState
    let actions: PcActions

    var body: some View {
        List {
            switch state.content {
            case let .pc(pc):
                PcSections(state: pc, actions: actions)
            case let .gone(message):
                ContentUnavailableView(state.title, systemImage: satelliteSymbol, description: Text(message))
                    .listRowBackground(EmptyView())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The sections of a paired PC's page, in the board's order.
private struct PcSections: View {
    let state: PcDetailState
    let actions: PcActions

    @State private var forgetAsked = false

    var body: some View {
        Section {
            PcStatusCard(state: state.status)
        }
        .listRowBackground(DishTheme.surface)
        Section {
            if let empty = state.carrying.empty {
                Text(empty).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
            ForEach(state.carrying.rows) { row in
                LabeledContent(row.name) {
                    Text(row.slot).font(DishFont.monoDetail).foregroundStyle(DishTheme.muted)
                }
                .foregroundStyle(DishTheme.onSurface)
            }
        } header: {
            SectionEyebrow(title: state.carrying.title, color: DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
        if let carries = state.carries {
            Section {
                HStack(alignment: .top, spacing: DishSpace.s8) {
                    CarryColumnView(column: carries.sends)
                    CarryColumnView(column: carries.getsBack)
                }
            } header: {
                SectionEyebrow(title: carries.title, color: DishTheme.muted)
            }
            .listRowBackground(DishTheme.surface)
        }
        Section {
            ForEach(state.actions) { action in
                Button(action.title) { actions.act(action.action) }
                    .foregroundStyle(DishTheme.primary)
            }
            Button(state.forget.button, role: .destructive, action: askForget)
                .confirmationDialog(state.forget.title, isPresented: $forgetAsked, titleVisibility: .visible) {
                    Button(state.forget.confirm, role: .destructive, action: actions.forget)
                    Button(state.forget.cancel, role: .cancel) {}
                } message: {
                    Text(state.forget.message)
                }
        }
        .listRowBackground(DishTheme.surface)
    }

    private func askForget() {
        forgetAsked = true
    }
}

/// The card at the head of the page: the PC's glyph, how its link stands,
/// and its version, protocol and address in mono.
private struct PcStatusCard: View {
    let state: PcStatusState

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            RowGlyph(symbol: state.symbol)
            VStack(alignment: .leading, spacing: DishSpace.s1) {
                HStack(spacing: DishSpace.s3) {
                    StatusDot(color: state.dot)
                    Text(state.line).font(DishFont.headline).foregroundStyle(DishTheme.onSurface)
                }
                Text(state.detail).font(DishFont.monoDetail).foregroundStyle(DishTheme.muted)
            }
        }
        .padding(.vertical, DishSpace.s4)
        .accessibilityElement(children: .combine)
    }
}

/// The boards' PCs, for the previews.
private enum PcPreview {
    static let living = ConnectionFact(
        id: "lr",
        name: "Living Room PC",
        address: "192.168.1.24",
        kind: .satellite,
        state: .online(latencyMs: 4, controllers: 2),
        boundControllerIds: ["pad", "on-screen"],
        satelliteVersion: "2.1.11",
        protocolVersion: 3,
        features: SatelliteFeaturesFact(motion: true, rumble: true)
    )
    static let office = ConnectionFact(
        id: "office",
        name: "Office PC",
        address: "192.168.1.31",
        kind: .satellite,
        state: .offline(lastSeen: nil)
    )
    static let controllers = [
        ControllerFact(id: "pad", name: "DualSense", link: .usbC, batteryPercent: 84, destination: nil),
        ControllerFact(id: "on-screen", name: "", link: .onScreen, batteryPercent: nil, destination: nil)
    ]

    static func facts(paired: [ConnectionFact]) -> ShellFacts {
        ShellFacts(
            controllers: controllers,
            attachedPads: [],
            paired: paired,
            found: [],
            scanning: false,
            session: nil,
            localNetwork: .allowed,
            preferences: PreferencesFacts(deviceName: "", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system),
            now: Date(timeIntervalSince1970: 1_800_000_000),
            setup: nil
        )
    }
}

#Preview("Online") {
    NavigationStack {
        PcDetailPageBody(state: pcDetailPageState(facts: PcPreview.facts(paired: [PcPreview.living]), id: "lr"), actions: .preview)
    }
}

#Preview("Offline") {
    NavigationStack {
        PcDetailPageBody(state: pcDetailPageState(facts: PcPreview.facts(paired: [PcPreview.office]), id: "office"), actions: .preview)
    }
}

#Preview("Gone") {
    NavigationStack {
        PcDetailPageBody(state: pcDetailPageState(facts: PcPreview.facts(paired: []), id: "office"), actions: .preview)
    }
}
