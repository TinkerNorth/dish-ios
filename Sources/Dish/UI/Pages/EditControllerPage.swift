// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What the edit page's controls do: each one an intent.
struct EditControllerActions {
    let setFeature: @MainActor (SlotSwitch, Bool) -> Void
    let setEmulateAs: @MainActor (EmulatedPad) -> Void
    /// A pad on a Moonlight host: the protocol's type, nil for Auto.
    let setHostEmulateAs: @MainActor (Int?) -> Void
    /// The Dead zones row: that page, pushed.
    let openDeadZones: @MainActor () -> Void

    /// Controls that do nothing, for a preview.
    @MainActor static let preview = EditControllerActions(
        setFeature: { _, _ in },
        setEmulateAs: { _ in },
        setHostEmulateAs: { _ in },
        openDeadZones: {}
    )
}

/// Controllers › a controller › Edit controller: what the pad is set to.
/// Emulate as, FUNCTIONS with the switches the pad has, and the Dead zones
/// row; each change lands as it is made, so there is no Done.
struct EditControllerPage: View {
    let id: String

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        EditControllerPageBody(
            state: editControllerPageState(controllers: model.shellFacts.controllers, id: id),
            actions: EditControllerActions(
                setFeature: setFeature,
                setEmulateAs: setEmulateAs,
                setHostEmulateAs: setHostEmulateAs,
                openDeadZones: openDeadZones
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
}

/// The page over its state, so a preview can draw every state.
struct EditControllerPageBody: View {
    let state: EditControllerPageState
    let actions: EditControllerActions

    var body: some View {
        List {
            switch state.content {
            case let .pad(pad):
                EditControllerSections(state: pad, actions: actions)
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

/// The sections of an attached pad's edit page, in the board's order.
private struct EditControllerSections: View {
    let state: EditControllerPadState
    let actions: EditControllerActions

    var body: some View {
        ControllerEmulateSection(state: state.emulate, setEmulateAs: actions.setEmulateAs, setHostEmulateAs: actions.setHostEmulateAs)
        if let functions = state.functions {
            ControllerFunctionsSection(state: functions, footnote: state.footnote, setFeature: actions.setFeature)
        } else {
            Section {} footer: {
                Text(state.footnote).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
        if let deadZones = state.deadZones {
            ControllerDeadZonesSection(title: deadZones, open: actions.openDeadZones)
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
        destination: DestinationFact(name: "Living Room PC", health: .online),
        family: .dualSense,
        emulateAs: .dualSense,
        features: features
    )
    NavigationStack {
        EditControllerPageBody(state: editControllerPageState(controllers: [pad], id: "pad"), actions: .preview)
    }
}

#Preview("On-screen gamepad") {
    let onScreen = ControllerFact(id: "on-screen", name: "", link: .onScreen, batteryPercent: nil, destination: nil)
    NavigationStack {
        EditControllerPageBody(state: editControllerPageState(controllers: [onScreen], id: "on-screen"), actions: .preview)
    }
}

#Preview("Gone") {
    NavigationStack {
        EditControllerPageBody(state: editControllerPageState(controllers: [], id: "pad"), actions: .preview)
    }
}
