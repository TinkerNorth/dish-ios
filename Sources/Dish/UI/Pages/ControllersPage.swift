// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// The Controllers tab (A2): the pads iOS sees, then Add a controller on its
/// own under the list. A row opens the controller's page.
struct ControllersPage: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        ControllersPageBody(
            state: controllersPageState(controllers: model.shellFacts.controllers),
            add: addController,
            open: open,
            play: play
        )
    }

    private func open(_ page: Page) {
        navigation.send(.push(page))
    }

    private func play() {
        navigation.send(.openPlay(.gamepad))
    }

    private func addController() {
        navigation.send(.openSetup(.addController))
    }
}

/// The page over its state, so a preview can draw every content state.
struct ControllersPageBody: View {
    let state: ControllersPageState
    let add: () -> Void
    let open: @MainActor (Page) -> Void
    let play: @MainActor () -> Void

    var body: some View {
        List {
            switch state.content {
            case let .list(rows):
                Section {
                    ForEach(rows) { ControllerRow(state: $0, open: open, play: play) }
                }
                .listRowBackground(DishTheme.surface)
            case let .empty(invitation):
                Section {
                    ControllersInvitation(text: invitation)
                }
                .listRowBackground(EmptyView())
            }
            Section {
                AddControllerButton(title: state.addTitle, hint: state.addHint, action: add)
            }
            .listRowBackground(EmptyView())
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { open(state.support.page) } label: {
                    Image(systemName: state.support.symbol).foregroundStyle(DishTheme.pulse)
                }
                .accessibilityLabel(state.support.title)
            }
        }
    }
}

#Preview("Controllers") {
    let living = DestinationFact(name: "Living Room PC", health: .online)
    let controllers = [
        ControllerFact(id: "1", name: "DualSense", link: .usbC, batteryPercent: 84, destination: living),
        ControllerFact(id: "2", name: "Xbox Wireless Controller", link: .bluetooth, batteryPercent: 41, destination: living),
        ControllerFact(id: "3", name: "On-screen gamepad", link: .onScreen, batteryPercent: nil, destination: living)
    ]
    NavigationStack {
        ControllersPageBody(state: controllersPageState(controllers: controllers), add: {}, open: { _ in }, play: {})
    }
}

#Preview("Host lost") {
    let lost = DestinationFact(name: "Living Room PC", health: .lost)
    let controllers = [
        ControllerFact(id: "1", name: "DualSense", link: .usbC, batteryPercent: 84, destination: lost),
        ControllerFact(id: "2", name: "Xbox Wireless Controller", link: .bluetooth, batteryPercent: 12, destination: lost),
        ControllerFact(
            id: "3",
            name: "On-screen gamepad",
            link: .onScreen,
            batteryPercent: nil,
            destination: DestinationFact(name: "Office PC", health: .unsteady)
        )
    ]
    NavigationStack {
        ControllersPageBody(state: controllersPageState(controllers: controllers), add: {}, open: { _ in }, play: {})
    }
}

#Preview("Empty") {
    NavigationStack {
        ControllersPageBody(state: controllersPageState(controllers: []), add: {}, open: { _ in }, play: {})
    }
}
