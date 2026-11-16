// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What the controller page does: its actions through the one dispatch its
/// row shares, and Edit, which pushes the edit page.
struct ControllerActions {
    let act: @MainActor (ControllerAction) -> Void
    let edit: @MainActor () -> Void

    /// Controls that do nothing, for a preview.
    @MainActor static let preview = ControllerActions(act: { _ in }, edit: {})
}

/// Controllers › a controller (C1): what the pad is and does. The status
/// card, the strip of what it offers (Open gamepad or the lent screens,
/// Reconnect, Bind to or Find a PC), BINDING with the PC it sends to and
/// the apply inline, TELEMETRY once it has reported, and Unbind at the
/// foot; Edit on the toolbar pushes what it is set to.
struct ControllerPage: View {
    let id: String

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        controllerBody
            .onAppear { model.pageAppeared(.controller) }
            .onDisappear { model.pageDisappeared(.controller) }
    }

    private var controllerBody: some View {
        ControllerPageBody(
            state: controllerPageState(
                controllers: model.shellFacts.controllers,
                paired: model.shellFacts.paired,
                apply: model.shellFacts.apply,
                pads: model.shellFacts.diagnostics.pads,
                port: model.shellFacts.port,
                id: id
            ),
            actions: ControllerActions(act: ControllerActionRouter(model: model, navigation: navigation).perform, edit: edit)
        )
    }

    private func edit() {
        navigation.send(.push(.editController(id: id)))
    }
}

/// The page over its state, so a preview can draw every state.
struct ControllerPageBody: View {
    let state: ControllerPageState
    let actions: ControllerActions

    var body: some View {
        List {
            switch state.content {
            case let .pad(pad):
                ControllerPadSections(state: pad, actions: actions)
            case let .gone(message):
                ContentUnavailableView(state.title, systemImage: "gamecontroller", description: Text(message))
                    .listRowBackground(EmptyView())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationSubtitle(state.subtitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let edit = state.edit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(edit, action: actions.edit)
                }
            }
        }
    }
}

/// The sections of an attached pad's page: the card, the strip under it,
/// BINDING, TELEMETRY and Unbind at the foot.
private struct ControllerPadSections: View {
    let state: ControllerPadState
    let actions: ControllerActions

    var body: some View {
        Section {
            ControllerStatusCard(state: state.status)
        }
        .listRowBackground(DishTheme.surface)
        if let strip = state.actions.strip {
            Section {
                ActionStrip(entries: strip, perform: actions.act)
            }
            .listRowBackground(EmptyView())
            .listRowInsets(EdgeInsets())
        }
        ControllerBindingSection(state: state.binding, apply: state.apply, retry: retry)
        if let telemetry = state.telemetry {
            ControllerTelemetrySection(state: telemetry)
        }
        if let unbind = state.actions.unbind {
            ControllerUnbindSection(item: unbind, perform: actions.act)
        }
    }

    /// Try again binds the pad to the same PC.
    private func retry(_ connectionId: String) {
        actions.act(.bind(slotId: state.id, connectionId: connectionId))
    }
}

#Preview("DualSense, bound") {
    let features = SlotSwitch.allCases.map { ControllerFeatureFact(feature: $0, enabled: $0 != .lightbar) }
    let pad = ControllerFact(
        id: "pad",
        name: "DualSense",
        link: .usbC,
        batteryPercent: 84,
        destination: DestinationFact(name: "Living Room PC", health: .online),
        family: .dualSense,
        emulateAs: .dualSense,
        features: features
    )
    let apply = ApplyFact(slotId: "pad", connectionId: "lr", progress: .done)
    NavigationStack {
        ControllerPageBody(state: controllerPageState(controllers: [pad], apply: apply, id: "pad"), actions: .preview)
    }
}

#Preview("Xbox, lent the touchpad and the mouse, PC lost") {
    let pad = ControllerFact(
        id: "pad",
        name: "Xbox Wireless Controller",
        link: .bluetooth,
        batteryPercent: 41,
        destination: DestinationFact(id: "lr", name: "Living Room PC", health: .lost),
        family: .xbox,
        emulateAs: .xboxWireless,
        features: [ControllerFeatureFact(feature: .rumble, enabled: true)],
        surfaces: [.touchpad, .mouse]
    )
    NavigationStack {
        ControllerPageBody(state: controllerPageState(controllers: [pad], id: "pad"), actions: .preview)
    }
}

#Preview("Xbox, unbound") {
    let pad = ControllerFact(
        id: "pad",
        name: "Xbox Wireless Controller",
        link: .bluetooth,
        batteryPercent: nil,
        destination: nil,
        family: .xbox,
        emulateAs: .xboxWireless,
        features: [ControllerFeatureFact(feature: .rumble, enabled: true)]
    )
    let living = ConnectionFact(id: "lr", name: "Living Room PC", address: "192.168.1.24", kind: .satellite, state: .offline(lastSeen: nil))
    NavigationStack {
        ControllerPageBody(state: controllerPageState(controllers: [pad], paired: [living], id: "pad"), actions: .preview)
    }
}

#Preview("Gone") {
    NavigationStack {
        ControllerPageBody(state: controllerPageState(controllers: [], id: "pad"), actions: .preview)
    }
}
