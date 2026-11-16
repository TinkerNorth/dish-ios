// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// The Controllers tab (A2): the pads iOS sees, then Add a controller on its
/// own under the list, and on a Lightning iPhone with nothing listed the
/// note that a wired pad needs the adapter, which opens its sheet. A row
/// opens the controller's page: pushed on a phone, beside the list on an
/// iPad.
struct ControllersPage: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation
    @Environment(\.windowFacts) private var window

    var body: some View {
        let layout = tabLayout(.controllers, width: window.width)
        ControllersPageBody(
            state: controllersPageState(
                controllers: model.controllersFacts.controllers,
                apply: model.controllersFacts.apply,
                paired: model.connectionsFacts.paired,
                port: model.controllersFacts.port
            ),
            layout: layout,
            selection: listSelection(navigation.listSelection(of: .controllers), layout: layout),
            add: addController,
            open: open,
            act: act,
            more: whatYouNeed
        )
    }

    /// The Lightning note's way to its sheet.
    private func whatYouNeed() {
        navigation.send(.openSheet(.lightningAdapter))
    }

    /// A row's page, or the heart's: alone on the tab.
    private func open(_ page: Page) {
        navigation.send(.show(page, in: .controllers))
    }

    /// A row's menu and swipes: the controller's actions, through the
    /// dispatch its page shares.
    private func act(_ action: ControllerAction) {
        ControllerActionRouter(model: model, navigation: navigation).perform(action)
    }

    private func addController() {
        navigation.send(.openSetup(.addController))
    }
}

/// The page over its state, so a preview can draw every content state. On
/// an iPad the list selects the controller shown beside it.
struct ControllersPageBody: View {
    let state: ControllersPageState
    var layout = TabLayout.stack
    /// The page beside the list; nil while the list is a stack's.
    var selection: Binding<Page?>?
    let add: () -> Void
    let open: @MainActor (Page) -> Void
    let act: @MainActor (ControllerAction) -> Void
    /// The Lightning note's way to its sheet.
    var more: @MainActor () -> Void = {}

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach(state.rows) { ControllerRow(state: $0, layout: layout, open: open, act: act) }
            }
            .listRowBackground(DishTheme.surface)
            if let adapter = state.adapter {
                Section {
                    AdapterNoteRow(state: adapter, more: more)
                }
                .listRowBackground(DishTheme.surface)
            }
            Section {
                AddControllerButton(title: state.addTitle, hint: state.addHint, tipKitHint: state.hints.add, action: add)
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
                .hint(state.hints.support)
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
        ControllersPageBody(state: controllersPageState(controllers: controllers), add: {}, open: { _ in }, act: { _ in })
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
            destination: DestinationFact(name: "Office PC", health: .connecting)
        )
    ]
    NavigationStack {
        ControllersPageBody(state: controllersPageState(controllers: controllers), add: {}, open: { _ in }, act: { _ in })
    }
}

#Preview("Empty") {
    NavigationStack {
        ControllersPageBody(state: controllersPageState(controllers: []), add: {}, open: { _ in }, act: { _ in })
    }
}

#Preview("Empty, Lightning iPhone") {
    NavigationStack {
        ControllersPageBody(state: controllersPageState(controllers: [], port: .lightning), add: {}, open: { _ in }, act: { _ in })
    }
}
