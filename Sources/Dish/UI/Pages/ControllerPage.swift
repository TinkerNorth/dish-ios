// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What the controller page's rows do: each one an intent.
struct ControllerActions {
    let setFeature: @MainActor (SlotSwitch, Bool) -> Void
    let setEmulateAs: @MainActor (EmulatedPad) -> Void
    /// The on-screen controller's Open: its gamepad.
    let open: @MainActor () -> Void
}

/// Controllers › a controller (C1) without its PC half: the status card,
/// BINDING with its destination (filled by the binding wave) and Emulate as,
/// and the switches the pad has. Telemetry waits until it is measured.
struct ControllerPage: View {
    let id: String

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        ControllerPageBody(
            state: controllerPageState(controllers: model.shellFacts.controllers, id: id),
            actions: ControllerActions(setFeature: setFeature, setEmulateAs: setEmulateAs, open: openGamepad)
        )
    }

    private func setFeature(_ feature: SlotSwitch, _ enabled: Bool) {
        model.setControllerFeature(slotId: id, feature, enabled: enabled)
    }

    private func setEmulateAs(_ pad: EmulatedPad) {
        model.setEmulatedType(slotId: id, pad)
    }

    private func openGamepad() {
        navigation.send(.openPlay(.gamepad))
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
            if let open = state.open {
                Button(open, systemImage: PlaySymbol.resume, action: actions.open)
                    .font(DishFont.headline)
                    .foregroundStyle(DishTheme.primary)
            }
        }
        .listRowBackground(DishTheme.surface)
        ControllerBindingSection(state: state.binding, setEmulateAs: actions.setEmulateAs)
        if let functions = state.functions {
            ControllerFunctionsSection(state: functions, footnote: state.footnote, setFeature: actions.setFeature)
        } else {
            Section {} footer: {
                Text(state.footnote).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
    }
}

#Preview("DualSense") {
    let features = SlotSwitch.allCases.map { ControllerFeatureFact(feature: $0, enabled: $0 != .lightbar) }
    let pad = ControllerFact(
        id: "pad",
        name: "DualSense",
        link: .usbC,
        batteryPercent: 84,
        destination: nil,
        family: .dualSense,
        emulateAs: .dualSense,
        features: features
    )
    NavigationStack {
        ControllerPageBody(
            state: controllerPageState(controllers: [pad], id: "pad"),
            actions: ControllerActions(setFeature: { _, _ in }, setEmulateAs: { _ in }, open: {})
        )
    }
}

#Preview("Xbox") {
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
    NavigationStack {
        ControllerPageBody(
            state: controllerPageState(controllers: [pad], id: "pad"),
            actions: ControllerActions(setFeature: { _, _ in }, setEmulateAs: { _ in }, open: {})
        )
    }
}

#Preview("Gone") {
    NavigationStack {
        ControllerPageBody(
            state: controllerPageState(controllers: [], id: "pad"),
            actions: ControllerActions(setFeature: { _, _ in }, setEmulateAs: { _ in }, open: {})
        )
    }
}
