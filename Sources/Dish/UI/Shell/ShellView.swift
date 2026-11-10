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
        .modifier(SessionAccessory(state: sessionBarState(model.shellFacts.session), dim: dim, play: play))
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(item: navigation.cover) { ShellCover(cover: $0) }
    }

    private func dim() {
        navigation.send(.dim)
    }

    private func play() {
        navigation.send(.openPlay(.gamepad))
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
        case let .controller(id): ControllerPage(id: id)
        case .help: HelpPage()
        case .licenses: LicensesPage()
        case .support: SupportPage()
        case .diagnostics: DiagnosticsPage()
        }
    }
}

/// The accessory, attached only while there is a session to show: iOS 26.0
/// has no `isEnabled:` form, and an empty accessory still draws its glass.
/// Play opens the on-screen gamepad; Reconnect arrives with the session wave.
private struct SessionAccessory: ViewModifier {
    let state: SessionBarState?
    let dim: () -> Void
    let play: () -> Void

    func body(content: Content) -> some View {
        if let state {
            content.tabViewBottomAccessory {
                SessionBar(state: state, dim: dim, play: play, reconnect: nil)
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
        case .setup: SetupCover()
        case let .play(screen): PlayCover(screen: screen)
        case .dim: DimCover()
        }
    }
}

/// One presentation per kind of cover: the pause menu moving from one play
/// screen to another keeps the cover up and swaps what it draws.
enum CoverIdentity: Hashable {
    case setup(SetupEntry)
    case play
    case dim
}

extension Cover: Identifiable {
    var id: CoverIdentity {
        switch self {
        case let .setup(entry): .setup(entry)
        case .play: .play
        case .dim: .dim
        }
    }
}
