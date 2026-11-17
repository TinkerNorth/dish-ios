// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What the controller page does: its settings, each an intent, and Unbind
/// through the one dispatch its row shares.
struct ControllerActions {
    let act: @MainActor (ControllerAction) -> Void
    let setFeature: @MainActor (SlotSwitch, Bool) -> Void
    let setEmulateAs: @MainActor (EmulatedPad) -> Void
    /// A pad on a Moonlight host: the protocol's type, nil for Auto.
    let setHostEmulateAs: @MainActor (Int?) -> Void
    /// The Dead zones row: that page, pushed.
    let openDeadZones: @MainActor () -> Void
    /// A Steam Controller's trackpads.
    let setTrackpads: @MainActor (TouchpadPick) -> Void

    /// Controls that do nothing, for a preview.
    @MainActor static let preview = ControllerActions(
        act: { _ in },
        setFeature: { _, _ in },
        setEmulateAs: { _ in },
        setHostEmulateAs: { _ in },
        openDeadZones: {},
        setTrackpads: { _ in }
    )
}

/// Controllers › a controller (C1): what the pad is set to, over where it
/// sends. The status card, BINDING with the PC it sends to and the apply
/// inline, Emulate as, FUNCTIONS with the switches the pad has, the Dead
/// zones row, TELEMETRY once it has reported, and Unbind at the foot; each
/// change lands as it is made, so there is no Done. What the pad offers to
/// do is its row's.
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
                controllers: model.controllersFacts.controllers,
                paired: model.connectionsFacts.paired,
                apply: model.controllersFacts.apply,
                pads: model.diagnosticsFacts.snapshot.pads,
                port: model.controllersFacts.port,
                id: id
            ),
            actions: ControllerActions(
                act: ControllerActionRouter(model: model, navigation: navigation).perform,
                setFeature: setFeature,
                setEmulateAs: setEmulateAs,
                setHostEmulateAs: setHostEmulateAs,
                openDeadZones: openDeadZones,
                setTrackpads: setTrackpads
            )
        )
    }

    private func setFeature(_ feature: SlotSwitch, _ enabled: Bool) {
        model.setControllerFeature(slotId: id, feature, enabled: enabled)
    }

    private func setEmulateAs(_ pad: EmulatedPad) {
        model.setEmulatedType(slotId: id, pad)
    }

    private func setHostEmulateAs(_ type: Int?) {
        model.setMoonlightEmulatedType(slotId: id, type)
    }

    private func openDeadZones() {
        navigation.send(.push(.deadZones(id: id)))
    }

    private func setTrackpads(_ pick: TouchpadPick) {
        model.setTrackpadPick(slotId: id, pick)
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
    }
}

/// The sections of an attached pad's page, in the board's order.
private struct ControllerPadSections: View {
    let state: ControllerPadState
    let actions: ControllerActions

    var body: some View {
        Section {
            ControllerStatusCard(state: state.status)
        }
        .listRowBackground(DishTheme.surface)
        ControllerBindingSection(state: state.binding, apply: state.apply, updating: state.updating, bind: bind, findPC: findPC)
        ControllerEmulateSection(state: state.emulate, setEmulateAs: actions.setEmulateAs, setHostEmulateAs: actions.setHostEmulateAs)
        if let functions = state.functions {
            ControllerFunctionsSection(
                state: functions,
                footnote: state.footnote,
                setFeature: actions.setFeature,
                setTrackpads: actions.setTrackpads
            )
        } else {
            Section {} footer: {
                Text(state.footnote).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
        if let deadZones = state.deadZones {
            ControllerDeadZonesSection(title: deadZones, open: actions.openDeadZones)
        }
        if let telemetry = state.telemetry {
            ControllerTelemetrySection(state: telemetry)
        }
        if let unbind = state.unbind {
            ControllerUnbindSection(item: unbind, perform: actions.act)
        }
    }

    /// A PC picked, or Try again on the same one.
    private func bind(_ connectionId: String) {
        actions.act(.bind(slotId: state.id, connectionId: connectionId))
    }

    private func findPC() {
        actions.act(.findPC)
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

#Preview("On-screen gamepad") {
    let onScreen = ControllerFact(id: "on-screen", name: "", link: .onScreen, batteryPercent: nil, destination: nil)
    NavigationStack {
        ControllerPageBody(state: controllerPageState(controllers: [onScreen], id: "on-screen"), actions: .preview)
    }
}

#Preview("Steam Controller (2026), Bluetooth") {
    let pad = ControllerFact(
        id: "ble:pad",
        name: "Valve Steam Controller (2026, Bluetooth)",
        link: .bluetooth,
        batteryPercent: nil,
        destination: nil,
        features: [ControllerFeatureFact(feature: .motion, enabled: true), ControllerFeatureFact(feature: .rumble, enabled: true)],
        trackpads: TrackpadsFact(choices: [.pad, .off], pick: .off)
    )
    NavigationStack {
        ControllerPageBody(state: controllerPageState(controllers: [pad], id: "ble:pad"), actions: .preview)
    }
}

#Preview("Gone") {
    NavigationStack {
        ControllerPageBody(state: controllerPageState(controllers: [], id: "pad"), actions: .preview)
    }
}
