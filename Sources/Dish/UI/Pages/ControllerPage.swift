// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What the controller page's rows do: each one an intent.
struct ControllerActions {
    let setFeature: @MainActor (SlotSwitch, Bool) -> Void
    let setEmulateAs: @MainActor (EmulatedPad) -> Void
    /// A pad on a Moonlight host: the protocol's type, nil for Auto.
    let setHostEmulateAs: @MainActor (Int?) -> Void
    /// The on-screen controller's Open: its gamepad.
    let open: @MainActor () -> Void
    /// Bind to the PC, by its connection id; Try again binds to the same one.
    let bind: @MainActor (String) -> Void
    let unbind: @MainActor () -> Void

    /// Controls that do nothing, for a preview.
    @MainActor static let preview = ControllerActions(
        setFeature: { _, _ in },
        setEmulateAs: { _ in },
        setHostEmulateAs: { _ in },
        open: {},
        bind: { _ in },
        unbind: {}
    )
}

/// Controllers › a controller (C1): the status card, BINDING with the PC it
/// sends to or the paired PCs to bind to, the apply inline, Emulate as, and
/// the switches the pad has. Telemetry waits until it is measured.
struct ControllerPage: View {
    let id: String

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        ControllerPageBody(
            state: controllerPageState(
                controllers: model.shellFacts.controllers,
                paired: model.shellFacts.paired,
                apply: model.shellFacts.apply,
                id: id
            ),
            actions: ControllerActions(
                setFeature: setFeature,
                setEmulateAs: setEmulateAs,
                setHostEmulateAs: setHostEmulateAs,
                open: openGamepad,
                bind: bind,
                unbind: unbind
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

    private func openGamepad() {
        navigation.send(.openPlay(.gamepad))
    }

    private func bind(_ connectionId: String) {
        model.bind(slotId: id, to: connectionId)
    }

    private func unbind() {
        model.unbind(slotId: id)
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
        ControllerBindingSection(state: state.binding, apply: state.apply, actions: actions)
        if let functions = state.functions {
            ControllerFunctionsSection(state: functions, footnote: state.footnote, setFeature: actions.setFeature)
        } else {
            Section {} footer: {
                Text(state.footnote).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
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

#Preview("Gone") {
    NavigationStack {
        ControllerPageBody(state: controllerPageState(controllers: [], id: "pad"), actions: .preview)
    }
}
