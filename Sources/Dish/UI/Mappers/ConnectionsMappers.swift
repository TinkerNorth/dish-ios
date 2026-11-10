// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What a row's button, menu and swipes do: Pair (and Re-pair) opens the
/// sheet, Connect reaches for the PC, Disconnect closes its session, and
/// Forget drops it once the person confirmed.
enum ConnectionRowAction: Hashable {
    case pair(serverId: String)
    case connect(id: String)
    case disconnect(id: String)
    case forget(id: String)
}

/// A row's one button, when its state calls for one.
struct ConnectionRowButton: Equatable {
    let title: String
    let action: ConnectionRowAction
}

/// One PC row (D1): a paired row opens its page; a found or resting one
/// carries a button.
struct ConnectionRowState: Equatable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let line: String
    let dot: Color
    /// Nil while the row needs no button: a paired PC whose session is up.
    let button: ConnectionRowButton?
    /// The PC's page; nil for a PC Dish has not paired with.
    let page: Page?
    /// The long-press menu and the swipes.
    let actions: RowActionsState<ConnectionRowAction>
    /// What Forget This PC asks first; nil for a PC Dish has not paired with.
    let forget: ForgetPcState?
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

/// What the Connections tab shows under its title.
enum ConnectionsContent: Equatable {
    case denied(NetworkDeniedState)
    case empty(title: String, body: String)
    case list(ConnectionsListState)
}

/// The Connections tab: its title, the toolbar's Add a PC by address, and
/// the content.
struct ConnectionsPageState: Equatable {
    let title: String
    let add: String
    let content: ConnectionsContent
}

/// `facts.now` words an offline PC's last sighting; `settingsURL` is where
/// Open Settings goes.
func connectionsPageState(facts: ShellFacts, settingsURL: URL?, words: L10n = .app) -> ConnectionsPageState {
    ConnectionsPageState(
        title: tabTitle(.connections, words: words),
        add: words.addAPCByAddress,
        content: connectionsContent(facts, settingsURL: settingsURL, words: words)
    )
}

private func connectionsContent(_ facts: ShellFacts, settingsURL: URL?, words: L10n) -> ConnectionsContent {
    switch facts.localNetwork {
    case .denied: .denied(networkDenied(settingsURL: settingsURL, words: words))
    case .unknown, .allowed: reachablePage(facts, words: words)
    }
}

/// With nothing paired, found or being looked for, a short empty state.
private func reachablePage(_ facts: ShellFacts, words: L10n) -> ConnectionsContent {
    let nothingYet = facts.paired.isEmpty && facts.found.isEmpty && !facts.scanning
    guard !nothingYet else { return .empty(title: words.noPCsYet, body: words.noPCsYetBody) }
    return .list(connectionsList(facts, now: facts.now, words: words))
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
    return PairedSectionState(title: words.paired, rows: paired.map { connectionRow($0, now: now, paired: true, words: words) })
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

func connectionRow(_ connection: ConnectionFact, now: Date, paired: Bool = false, words: L10n = .app) -> ConnectionRowState {
    ConnectionRowState(
        id: connection.id,
        symbol: connectionSymbol(connection.kind),
        name: connectionTitle(connection),
        line: connectionLine(connection, now: now, words: words),
        dot: connectionDot(connection.state),
        button: rowButton(connection, paired: paired, words: words),
        page: paired ? .pcDetail(id: connection.id) : nil,
        actions: connectionRowActions(connection, paired: paired, words: words),
        forget: paired ? forgetState(bound: connection.boundControllerIds.count, words: words) : nil
    )
}

/// A paired PC: Connect while it rests or Disconnect while its session is
/// up, Re-pair, and Forget This PC; the first of them also under a swipe
/// from the leading edge, Forget under one from the trailing edge. A PC
/// found on the network: Pair, also under a leading swipe.
func connectionRowActions(_ connection: ConnectionFact, paired: Bool, words: L10n = .app) -> RowActionsState<ConnectionRowAction> {
    guard paired else { return foundActions(connection.id, words: words) }
    let first = pairedFirstAction(connection, words: words)
    let repair = RowActionItem(
        action: ConnectionRowAction.pair(serverId: connection.id),
        title: words.repair,
        symbol: RowActionSymbol.repair,
        destructive: false
    )
    let forget = RowActionItem(
        action: ConnectionRowAction.forget(id: connection.id),
        title: words.forgetThisPC,
        symbol: RowActionSymbol.forget,
        destructive: true
    )
    let menu = (first + [repair, forget]).map(RowMenuEntry.item)
    return RowActionsState(menu: menu, leading: first.isEmpty ? [repair] : first, trailing: [forget])
}

private func foundActions(_ id: String, words: L10n) -> RowActionsState<ConnectionRowAction> {
    let pair = RowActionItem(
        action: ConnectionRowAction.pair(serverId: id),
        title: words.pair,
        symbol: RowActionSymbol.pair,
        destructive: false
    )
    return RowActionsState(menu: [.item(pair)], leading: [pair], trailing: [])
}

/// Disconnect while the session is up, Connect while the PC rests, and
/// neither while its key was revoked, as on the PC's page.
private func pairedFirstAction(_ connection: ConnectionFact, words: L10n) -> [RowActionItem<ConnectionRowAction>] {
    switch connection.state {
    case .online:
        [RowActionItem(
            action: .disconnect(id: connection.id),
            title: words.disconnect,
            symbol: RowActionSymbol.disconnect,
            destructive: false
        )]
    case .offline:
        [RowActionItem(action: .connect(id: connection.id), title: words.connect, symbol: RowActionSymbol.connect, destructive: false)]
    case .needsPairing:
        []
    }
}

/// A PC's name, or its address when it never advertised one.
func connectionTitle(_ connection: ConnectionFact) -> String {
    connection.name.isEmpty ? connection.address : connection.name
}

/// Pair for a PC that wants a PIN, Connect for a paired one that rests, and
/// nothing while its session is up.
private func rowButton(_ connection: ConnectionFact, paired: Bool, words: L10n) -> ConnectionRowButton? {
    switch connection.state {
    case .online: nil
    case .offline: paired ? ConnectionRowButton(title: words.connect, action: .connect(id: connection.id)) : nil
    case .needsPairing: ConnectionRowButton(title: words.pair, action: .pair(serverId: connection.id))
    }
}

/// The Bluetooth rung of the fleet's ladder is Android's own gamepad
/// layer; no PC on iOS is one, so it draws as the client's own wire.
func connectionSymbol(_ kind: ConnectionKind) -> String {
    switch kind {
    case .satellite, .bluetooth: satelliteSymbol
    case .moonlight: "desktopcomputer"
    }
}

/// A row's second line: the link with its latency and pads, when the PC was
/// last seen, or that it wants a PIN at its address.
func connectionLine(_ connection: ConnectionFact, now: Date, words: L10n = .app) -> String {
    switch connection.state {
    case let .online(latencyMs, controllers):
        [words.online, words.latency(latencyMs), words.controllerCount(controllers)].joined(separator: lineSeparator)
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
