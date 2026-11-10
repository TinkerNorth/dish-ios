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
