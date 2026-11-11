// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// One tab as the tab bar draws it.
struct TabItemState: Equatable, Identifiable {
    let tab: Tab
    let title: String
    let symbol: String
    /// Nil when there is nothing to call out.
    let badge: Int?

    var id: Tab {
        tab
    }

    /// The count `badge(_:)` takes, where zero draws nothing.
    var badgeCount: Int {
        badge ?? 0
    }
}

/// The session accessory: the live link on every tab.
enum SessionBarState: Equatable {
    /// `line` under the PC's name; `shortLine` alone while the tab bar is
    /// minimized. `dim` and `play` label the two buttons.
    case streaming(pcName: String, line: String, shortLine: String, dim: String, play: String)
    /// The PC stopped answering: the warning line and Reconnect.
    case problem(pcName: String, line: String, reconnect: String)
}

func tabItems(facts: ShellFacts, words: L10n = .app) -> [TabItemState] {
    Tab.allCases.map { tab in
        TabItemState(tab: tab, title: tabTitle(tab, words: words), symbol: tabSymbol(tab), badge: tabBadge(tab, facts: facts))
    }
}

func tabTitle(_ tab: Tab, words: L10n = .app) -> String {
    switch tab {
    case .controllers: words.controllers
    case .connections: words.connections
    case .settings: words.settings
    }
}

/// A pushed page's title, worded in one place so the map stays whole
/// (NavigationCoverageTests).
func pageTitle(_ page: Page, words: L10n = .app) -> String {
    switch page {
    case .deviceName: words.nameOnYourPC
    case .controller: words.controller
    case .pcDetail: words.pc
    case .help: words.helpAndFaq
    case .licenses: words.openSourceLicenses
    case .support: words.supportDish
    case .diagnostics: words.diagnostics
    case .moonlightHosts: words.moonlightHosts
    case .deadZones: words.deadZones
    }
}

func tabSymbol(_ tab: Tab) -> String {
    switch tab {
    case .controllers: "gamecontroller"
    case .connections: satelliteSymbol
    case .settings: "gearshape"
    }
}

/// SF Symbols has no satellite; the antenna stands in for it on the tab,
/// the session accessory and a Satellite PC's row.
let satelliteSymbol = "antenna.radiowaves.left.and.right"

private func tabBadge(_ tab: Tab, facts: ShellFacts) -> Int? {
    switch tab {
    case .connections: connectionsBadge(session: facts.session)
    case .controllers, .settings: nil
    }
}

/// The satellite whose card the model opened, which the shell's pair sheet
/// follows; nil lowers the sheet.
func pairingSheetId(_ open: OpenPairing?) -> String? {
    open?.server.id
}

/// One badge while the session's PC has stopped responding, shown once.
func connectionsBadge(session: SessionFact?) -> Int? {
    switch session?.phase {
    case .stoppedResponding: 1
    case .streaming, nil: nil
    }
}

func sessionBarState(_ session: SessionFact?, words: L10n = .app) -> SessionBarState? {
    guard let session else { return nil }
    switch session.phase {
    case .streaming: return streamingBar(session, words: words)
    case .stoppedResponding: return .problem(pcName: session.pcName, line: words.stoppedResponding, reconnect: words.reconnect)
    }
}

private func streamingBar(_ session: SessionFact, words: L10n) -> SessionBarState {
    let counts = [words.padCount(session.pads)] + [session.latencyMs.map(words.latency)].compactMap(\.self)
    let shortLine = counts.joined(separator: lineSeparator)
    let line = ([words.streaming] + counts).joined(separator: lineSeparator)
    return .streaming(pcName: session.pcName, line: line, shortLine: shortLine, dim: words.dim, play: words.play)
}

// MARK: - A tab's list beside its page, on a regular width

/// How a tab is drawn: one stack, or its list beside the page it opens.
enum TabLayout: Equatable {
    case stack
    case split
}

/// On a regular width (an iPad) the tabs whose list opens a page of its own,
/// Controllers and Connections, draw the list beside the page; Settings, a
/// list of settings, and every tab on a compact width keep their stack.
func tabLayout(_ tab: Tab, width: SizeClass) -> TabLayout {
    switch (tab, width) {
    case (.controllers, .regular), (.connections, .regular): .split
    case (.settings, _), (_, .compact): .stack
    }
}

/// A split's list selects the page beside it; a stack's list selects
/// nothing, and its rows push.
func listSelection(_ selection: Binding<Page?>, layout: TabLayout) -> Binding<Page?>? {
    switch layout {
    case .stack: nil
    case .split: selection
    }
}

/// What a tap on a list's row does.
enum RowOpening: Equatable {
    /// A stack's row pushes its page, with a chevron.
    case push(Page)
    /// A split list's row is selected, and its page shows beside the list.
    case select(Page)
    /// A row with no page opens nothing.
    case inert
}

func rowOpening(_ page: Page?, layout: TabLayout) -> RowOpening {
    guard let page else { return .inert }
    switch layout {
    case .stack: return .push(page)
    case .split: return .select(page)
    }
}

/// The column beside a split tab's list.
enum TabDetailState: Equatable {
    /// The page the list opened.
    case page(Page)
    /// Nothing opened yet: the invitation to pick one of the list's rows.
    case pick(title: String, symbol: String)
    /// Nothing opened, and the list has nothing to open.
    case blank
}

func tabDetailState(_ tab: Tab, opened: Page?, facts: ShellFacts, words: L10n = .app) -> TabDetailState {
    guard let opened else { return detailInvitation(tab, facts: facts, words: words) }
    return .page(opened)
}

/// A controller Dish can read, or a paired PC, is a row that opens a page.
private func detailInvitation(_ tab: Tab, facts: ShellFacts, words: L10n) -> TabDetailState {
    switch tab {
    case .controllers:
        let somethingToOpen = facts.controllers.contains(where: \.supported)
        return somethingToOpen ? .pick(title: words.pickAController, symbol: tabSymbol(.controllers)) : .blank
    case .connections:
        let somethingToOpen = !facts.paired.isEmpty
        return somethingToOpen ? .pick(title: words.pickAPC, symbol: satelliteSymbol) : .blank
    case .settings:
        return .blank
    }
}

/// iOS suspends Dish when the screen locks, so the idle timer is held off
/// while a session is up and the person asked to keep the screen on.
func idleTimerDisabled(facts: ShellFacts) -> Bool {
    let sessionUp = facts.session != nil
    return sessionUp && facts.preferences.keepScreenOn
}

/// The scheme the Appearance setting forces; nil follows the system.
func colorScheme(for appearance: Appearance) -> ColorScheme? {
    switch appearance {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
}
