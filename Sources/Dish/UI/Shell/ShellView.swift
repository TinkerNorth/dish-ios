// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// The three tabs, each its own stack, the session accessory on every tab
/// while a session is up, the sheets over the tabs, and the covers over all
/// of it. On an iPad the tabs open into a sidebar, and Controllers and
/// Connections draw their list beside the page it opens. The model's
/// pairing card opening or closing moves the pair sheet.
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
        .tabViewStyle(.sidebarAdaptable)
        .modifier(SessionAccessory(state: sessionBarState(model.shellFacts.session), dim: dim, play: play, reconnect: model.reconnect))
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: navigation.tabsSheet) { ShellSheet(sheet: $0) }
        .fullScreenCover(item: navigation.cover) { ShellCover(cover: $0) }
        .onChange(of: pairingSheetId(model.openPairing)) { _, serverId in pairingChanged(serverId) }
    }

    private func dim() {
        navigation.send(.dim)
    }

    private func play() {
        navigation.send(.openPlay(.gamepad))
    }

    private func pairingChanged(_ serverId: String?) {
        navigation.send(.pairingChanged(serverId: serverId))
    }
}

/// One tab: its root page and the pages pushed onto it, or, on a regular
/// width, its list beside the page the list opened.
private struct TabStack: View {
    let tab: Tab

    @Environment(NavigationStore.self) private var navigation
    @Environment(\.windowFacts) private var window

    var body: some View {
        switch tabLayout(tab, width: window.width) {
        case .stack:
            NavigationStack(path: navigation.path(of: tab)) {
                root.navigationDestination(for: Page.self) { PageView(page: $0) }
            }
        case .split:
            NavigationSplitView {
                root
            } detail: {
                TabDetail(tab: tab)
            }
            .navigationSplitViewStyle(.balanced)
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

/// The column beside a split tab's list: the page the list opened, in a
/// stack of its own for what that page pushes. Another row's page starts
/// afresh: a PC's page asking to forget one PC does not ask for the next.
private struct TabDetail: View {
    let tab: Tab

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        let opened = navigation.state.opened(in: tab)
        NavigationStack(path: navigation.detailPath(of: tab)) {
            TabDetailRoot(state: tabDetailState(tab, opened: opened, facts: model.shellFacts))
                .id(opened)
                .navigationDestination(for: Page.self) { PageView(page: $0) }
        }
    }
}

/// The detail column's own page: the one opened, or before one is, the
/// invitation to pick a row of the list.
private struct TabDetailRoot: View {
    let state: TabDetailState

    var body: some View {
        switch state {
        case let .page(page):
            PageView(page: page)
        case let .pick(title, symbol):
            ContentUnavailableView(title, systemImage: symbol)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DishTheme.background)
        case .blank:
            DishTheme.background.ignoresSafeArea()
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
        case let .pcDetail(id): PcDetailPage(id: id)
        case .help: HelpPage()
        case .licenses: LicensesPage()
        case .support: SupportPage()
        case .diagnostics: DiagnosticsPage()
        case .moonlightHosts: MoonlightHostsPage()
        case let .deadZones(id): DeadZonesPage(id: id)
        }
    }
}

/// The accessory, attached only while there is a session to show: iOS 26.0
/// has no `isEnabled:` form, and an empty accessory still draws its glass.
/// Play opens the on-screen gamepad; Reconnect brings a stopped PC back.
private struct SessionAccessory: ViewModifier {
    let state: SessionBarState?
    let dim: () -> Void
    let play: () -> Void
    let reconnect: () -> Void

    func body(content: Content) -> some View {
        if let state {
            content.tabViewBottomAccessory {
                SessionBar(state: state, dim: dim, play: play, reconnect: reconnect, dimHint: hintState(.dim))
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

/// The shell as an iPad draws it: the size classes are the iPad's, and the
/// scene's own reader hands them down, with the canvas's shape.
private struct ShellPreviewOnAnIPad: View {
    var body: some View {
        ShellView()
            .modifier(WindowReader())
            .environment(\.horizontalSizeClass, .regular)
            .environment(\.verticalSizeClass, .regular)
            .environment(PreviewSetup.emptyModel())
            .environment(PreviewSetup.tabsNavigation())
    }
}

#Preview("iPad on its side", traits: .landscapeLeft) {
    ShellPreviewOnAnIPad()
}

#Preview("iPad upright", traits: .portrait) {
    ShellPreviewOnAnIPad()
}
