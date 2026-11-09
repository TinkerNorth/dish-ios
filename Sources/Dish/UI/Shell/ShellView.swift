// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// The three tabs, each its own stack, the session accessory on every tab
/// while a session is up, and the covers over all of it.
struct ShellView: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        TabView(selection: navigation.tab) {
            ForEach(tabItems(facts: model.shellFacts)) { item in
                SwiftUI.Tab(item.title, systemImage: item.symbol, value: item.tab) {
                    TabStack(tab: item.tab)
                }
                .badge(item.badgeCount)
            }
        }
        .modifier(SessionAccessory(state: sessionBarState(model.shellFacts.session), dim: dim))
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(item: navigation.cover) { ShellCover(cover: $0) }
    }

    private func dim() {
        navigation.send(.dim)
    }
}

/// One tab's stack: its root page, and the pages pushed onto it.
private struct TabStack: View {
    let tab: Tab

    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        NavigationStack(path: navigation.path(of: tab)) {
            root.navigationDestination(for: Page.self) { PageView(page: $0) }
        }
    }

    @ViewBuilder private var root: some View {
        switch tab {
        case .controllers: ControllersPage()
        case .connections: ConnectionsPage()
        case .settings: SettingsPage()
        }
    }
}

/// A pushed page.
private struct PageView: View {
    let page: Page

    var body: some View {
        switch page {
        case .deviceName: DeviceNamePage()
        }
    }
}

/// The accessory, attached only while there is a session to show: iOS 26.0
/// has no `isEnabled:` form, and an empty accessory still draws its glass.
/// Play and Reconnect arrive with the play and session waves.
private struct SessionAccessory: ViewModifier {
    let state: SessionBarState?
    let dim: () -> Void

    func body(content: Content) -> some View {
        if let state {
            content.tabViewBottomAccessory {
                SessionBar(state: state, dim: dim, play: nil, reconnect: nil)
            }
        } else {
            content
        }
    }
}

/// What covers the tabs.
private struct ShellCover: View {
    let cover: Cover

    var body: some View {
        switch cover {
        case .setup: DishTheme.background.ignoresSafeArea()
        case .dim: Color.black.ignoresSafeArea()
        }
    }
}

extension Cover: Identifiable {
    var id: Self {
        self
    }
}
