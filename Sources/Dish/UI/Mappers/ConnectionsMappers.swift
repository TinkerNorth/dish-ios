// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// One PC row (D1). Connect and Pair arrive with the pairing wave.
struct ConnectionRowState: Equatable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let line: String
    let dot: Color
}

/// PAIRED and its rows.
struct PairedSectionState: Equatable {
    let title: String
    let rows: [ConnectionRowState]
}

/// FOUND ON <network>, with the spinner's word while discovery looks.
struct FoundSectionState: Equatable {
    let title: String
    /// Nil while discovery is not looking.
    let searching: String?
    let rows: [ConnectionRowState]
}

/// The sections, the Moonlight hosts row and the footnote.
struct ConnectionsListState: Equatable {
    /// Nil while nothing is paired.
    let paired: PairedSectionState?
    /// Nil while nothing is found and discovery is not looking.
    let found: FoundSectionState?
    let moonlightTitle: String
    let moonlightHint: String
    let footnote: String
}

/// D3: Local Network is off, so nothing else on the page can work.
struct NetworkDeniedState: Equatable {
    let title: String
    let body: String
    let openSettings: String
    /// Dish's page in the Settings app; nil hides the button.
    let settingsURL: URL?
    let caption: String
}

/// The Connections tab.
enum ConnectionsPageState: Equatable {
    case denied(NetworkDeniedState)
    case empty(title: String, body: String)
    case list(ConnectionsListState)
}

/// `now` words an offline PC's last sighting; `settingsURL` is where Open
/// Settings goes.
func connectionsPageState(facts: ShellFacts, now: Date, settingsURL: URL?, words: L10n = .app) -> ConnectionsPageState {
    switch facts.localNetwork {
    case .denied: .denied(networkDenied(settingsURL: settingsURL, words: words))
    case .unknown, .allowed: reachablePage(facts, now: now, words: words)
    }
}

/// With nothing paired, found or being looked for, a short empty state.
private func reachablePage(_ facts: ShellFacts, now: Date, words: L10n) -> ConnectionsPageState {
    let nothingYet = facts.paired.isEmpty && facts.found.isEmpty && !facts.scanning
    guard !nothingYet else { return .empty(title: words.noPCsYet, body: words.noPCsYetBody) }
    return .list(connectionsList(facts, now: now, words: words))
}

private func networkDenied(settingsURL: URL?, words: L10n) -> NetworkDeniedState {
    NetworkDeniedState(
        title: words.cantSeeYourNetwork,
        body: words.cantSeeYourNetworkBody,
        openSettings: words.openSettings,
        settingsURL: settingsURL,
        caption: words.localNetworkSettingsPath
    )
}

private func connectionsList(_ facts: ShellFacts, now: Date, words: L10n) -> ConnectionsListState {
    ConnectionsListState(
        paired: pairedSection(facts.paired, now: now, words: words),
        found: foundSection(facts, now: now, words: words),
        moonlightTitle: words.moonlightHosts,
        moonlightHint: words.moonlightHostsHint,
        footnote: words.connectionsFootnote
    )
}

private func pairedSection(_ paired: [ConnectionFact], now: Date, words: L10n) -> PairedSectionState? {
    guard !paired.isEmpty else { return nil }
    return PairedSectionState(title: words.paired, rows: paired.map { connectionRow($0, now: now, words: words) })
}

/// The network's name is not readable yet, so the title says "your Wi-Fi".
private func foundSection(_ facts: ShellFacts, now: Date, words: L10n) -> FoundSectionState? {
    let nothingToShow = facts.found.isEmpty && !facts.scanning
    guard !nothingToShow else { return nil }
    return FoundSectionState(
        title: words.foundOnYourWiFi,
        searching: facts.scanning ? words.searching : nil,
        rows: facts.found.map { connectionRow($0, now: now, words: words) }
    )
}

func connectionRow(_ connection: ConnectionFact, now: Date, words: L10n = .app) -> ConnectionRowState {
    ConnectionRowState(
        id: connection.id,
        symbol: connectionSymbol(connection.kind),
        name: connection.name,
        line: connectionLine(connection, now: now, words: words),
        dot: connectionDot(connection.state)
    )
}

func connectionSymbol(_ kind: ConnectionKind) -> String {
    switch kind {
    case .satellite: satelliteSymbol
    case .moonlight: "desktopcomputer"
    }
}

private func connectionLine(_ connection: ConnectionFact, now: Date, words: L10n) -> String {
    switch connection.state {
    case let .online(latencyMs, controllers): words.onlineLatencyControllers(latencyMs, controllers)
    case let .offline(lastSeen?): words.offlineSeen(relativeDay(lastSeen, now: now, words: words))
    case .offline(nil): words.offline
    case .needsPairing: words.needsPairingAt(connection.address)
    }
}

/// "yesterday", "2 hours ago", in the catalog's language.
func relativeDay(_ date: Date, now: Date, words: L10n = .app) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = words.catalog.locale
    formatter.dateTimeStyle = .named
    return formatter.localizedString(for: date, relativeTo: now)
}

func connectionDot(_ state: ConnectionState) -> Color {
    switch state {
    case .online: DishTheme.success
    case .offline: DishTheme.muted
    case .needsPairing: DishTheme.warning
    }
}
