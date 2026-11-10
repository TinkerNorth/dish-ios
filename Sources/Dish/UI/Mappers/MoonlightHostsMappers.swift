// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation
import SwiftUI

/// The Moonlight hosts page: the notice the last event left, the hosts
/// with the sweep's empty states, and the add-by-address form.
struct MoonlightHostsPageState: Equatable {
    let title: String
    let scan: String
    /// Nil while no host has said anything since the page opened.
    let notice: MoonlightNoticeState?
    let hosts: MoonlightHostsSectionState
    let add: MoonlightAddHostState
}

/// A host's last word, drawn above the rows: its glyph in the severity's
/// colour, and the way out when it is to close the host's app.
struct MoonlightNoticeState: Equatable {
    let symbol: String
    let tint: Color
    let title: String
    let body: String?
    let quit: MoonlightQuitAction?
}

struct MoonlightQuitAction: Equatable {
    let title: String
    let hostId: String
}

/// The hosts under FOUND ON, with the spinner's word while the sweep runs.
struct MoonlightHostsSectionState: Equatable {
    let title: String
    let searching: String?
    let list: MoonlightListState
}

enum MoonlightListState: Equatable {
    case looking(title: String, body: String)
    case nothing(MoonlightNothingFoundState)
    case rows([MoonlightHostRowState])
}

/// No host answered the sweep: where to get one.
struct MoonlightNothingFoundState: Equatable {
    let title: String
    let body: String
    let getSunshine: PageLink
}

struct MoonlightHostRowState: Equatable, Identifiable {
    let id: String
    let symbol: String
    let title: String
    let kindLine: String
    /// The trust word, the address and how many controllers ride the host.
    let line: String
    let dot: Color
    let statusLine: String?
    let app: AppPickerState?
    let actions: [MoonlightActionState]
    /// Nil for a host a scan found and nothing remembers: there is nothing to forget.
    let menu: MoonlightRowMenuState?
    let pin: MoonlightPinCardState?
}

struct MoonlightActionState: Equatable, Identifiable {
    let kind: MoonlightRowAction
    let title: String
    let enabled: Bool

    var id: String {
        title
    }
}

/// The app a host's session starts, once a probe has listed them: Auto (the
/// first the host lists) or the pick, shared by every pad on the host.
struct AppPickerState: Equatable {
    let label: String
    let options: [AppOption]
    let selection: String
    let note: String?
}

struct AppOption: Equatable, Identifiable {
    let id: String
    let title: String
}

/// The row's menu: Forget, which asks first.
struct MoonlightRowMenuState: Equatable {
    let label: String
    let forget: String
    let confirmTitle: String
    let confirmMessage: String
    let cancel: String
}

/// The PIN the dish minted, shown in the host's row for the user to type
/// into the host's own page while the exchange waits on it.
struct MoonlightPinCardState: Equatable {
    let title: String
    let cells: [String]
    let prompt: String
    let waiting: String
    let cancel: String
    let newCode: String
}

/// The form that adds a host mDNS does not reach: Add is live once
/// something is typed.
struct MoonlightAddHostState: Equatable {
    let heading: String
    let message: String
    let placeholder: String
    let add: String
    let canAdd: Bool
}

func moonlightHostsPageState(_ facts: MoonlightFacts, draft: String, words: L10n = .app) -> MoonlightHostsPageState {
    MoonlightHostsPageState(
        title: words.moonlightHosts,
        scan: words.moonlightScan,
        notice: facts.lastEvent.flatMap { moonlightNoticeState($0, words: words) },
        hosts: MoonlightHostsSectionState(
            title: words.foundOnYourWiFi,
            searching: facts.scanning ? words.searching : nil,
            list: moonlightList(facts, words: words)
        ),
        add: moonlightAddHostState(draft: draft, words: words)
    )
}

func moonlightAddHostState(draft: String, words: L10n = .app) -> MoonlightAddHostState {
    MoonlightAddHostState(
        heading: words.addAHostByAddress,
        message: words.enterTheHostAddressOrName,
        placeholder: words.moonlightAddressPlaceholder,
        add: words.moonlightAdd,
        canAdd: moonlightAddress(from: draft) != nil
    )
}

/// Empty is a real state, and it says so differently while a sweep runs.
func moonlightList(_ facts: MoonlightFacts, words: L10n = .app) -> MoonlightListState {
    let rows = moonlightRows(known: facts.hosts, discovered: facts.discovered)
    guard rows.isEmpty else { return .rows(rows.map { moonlightHostRow($0, facts, words: words) }) }
    guard !facts.scanning else { return .looking(title: words.lookingForMoonlightHosts, body: words.scanningForGameStreamHosts) }
    return .nothing(MoonlightNothingFoundState(
        title: words.noMoonlightHostsFound,
        body: words.moonlightHostAppearsHere,
        getSunshine: PageLink(title: words.getSunshine, url: DishLinks.sunshine)
    ))
}

func moonlightHostRow(_ row: MoonlightHostEntry, _ facts: MoonlightFacts, words: L10n = .app) -> MoonlightHostRowState {
    switch row {
    case let .known(summary): knownHostRow(summary, facts, words: words)
    case let .discovered(host): discoveredHostRow(host, facts, words: words)
    }
}

/// The trust word, the address and how many controllers ride the host; the
/// way out of where its session stands; Forget behind the menu.
func knownHostRow(_ summary: ConnectionSummary, _ facts: MoonlightFacts, words: L10n = .app) -> MoonlightHostRowState {
    let title = summary.recordName
    let phase = facts.phases[summary.id]
    let pairing = facts.pairingInFlight.contains(summary.id)
    let counts = [moonlightControllersText(summary, words: words)].compactMap(\.self)
    return MoonlightHostRowState(
        id: summary.id,
        symbol: connectionSymbol(.moonlight),
        title: title,
        kindLine: words.moonlightHostKind,
        line: ([moonlightTrustText(summary.live, words: words), summary.address] + counts).joined(separator: lineSeparator),
        dot: moonlightDot(summary.live),
        statusLine: moonlightStatusLine(summary, phase: phase, words: words),
        app: appPicker(summary.id, host: title, facts: facts, words: words),
        actions: moonlightActions(summary, phase: phase, host: title, enabled: !pairing, words: words),
        menu: moonlightRowMenu(host: title, words: words),
        pin: pinCard(on: summary.id, facts.pin, words: words)
    )
}

/// The row's buttons, each worded for its host; none runs while a pairing is in flight.
func moonlightActions(
    _ summary: ConnectionSummary,
    phase: MoonlightSessionPhase?,
    host: String,
    enabled: Bool,
    words: L10n = .app
) -> [MoonlightActionState] {
    moonlightRowActions(summary, phase: phase).map { action in
        MoonlightActionState(kind: action, title: moonlightActionText(action, host: host, words: words), enabled: enabled)
    }
}

/// A host only a scan knows: not paired, and Pair now is its one action.
func discoveredHostRow(_ host: MoonlightHost, _ facts: MoonlightFacts, words: L10n = .app) -> MoonlightHostRowState {
    let pairing = facts.pairingInFlight.contains(host.id)
    let pair = MoonlightActionState(kind: .pair, title: pairing ? words.moonlightPairing : words.moonlightPairNow, enabled: !pairing)
    return MoonlightHostRowState(
        id: host.id,
        symbol: connectionSymbol(.moonlight),
        title: moonlightHostTitle(host),
        kindLine: words.moonlightHostKind,
        line: [words.moonlightNotPaired, host.address].joined(separator: lineSeparator),
        dot: DishTheme.muted,
        statusLine: nil,
        app: nil,
        actions: [pair],
        menu: nil,
        pin: pinCard(on: host.id, facts.pin, words: words)
    )
}

func moonlightRowMenu(host: String, words: L10n = .app) -> MoonlightRowMenuState {
    MoonlightRowMenuState(
        label: words.moreActionsForHost(host),
        forget: words.moonlightForget,
        confirmTitle: words.forgetHostQuestion(host),
        confirmMessage: words.forgetMoonlightHelp(host),
        cancel: words.moonlightCancel
    )
}

/// Auto first, then each listed app by its title, its id when it has none.
func appPicker(_ hostId: String, host: String, facts: MoonlightFacts, words: L10n = .app) -> AppPickerState? {
    guard let apps = facts.apps[hostId], !apps.isEmpty else { return nil }
    let picked = facts.pickedApps[hostId] ?? ""
    let listed = apps.map { AppOption(id: $0.id, title: $0.title.isEmpty ? $0.id : $0.title) }
    return AppPickerState(
        label: words.moonlightApp,
        options: [AppOption(id: "", title: words.moonlightAuto)] + listed,
        selection: picked,
        note: picked.isEmpty ? words.withoutAPick(host) : nil
    )
}

func pinCard(on hostId: String, _ prompt: MoonlightPinPrompt?, words: L10n = .app) -> MoonlightPinCardState? {
    guard let prompt, prompt.host.id == hostId else { return nil }
    let host = moonlightHostTitle(prompt.host)
    return MoonlightPinCardState(
        title: words.pairWithHost(host),
        cells: prompt.pin.map(String.init),
        prompt: words.typePinInto(prompt.pin, host),
        waiting: words.waitingForTheHostToAcceptThePin,
        cancel: words.moonlightCancel,
        newCode: words.moonlightNewCode
    )
}

/// The last event as the page's notice, with the way out when the host's
/// app is in the way.
func moonlightNoticeState(_ event: MoonlightConnectionEvent, words: L10n = .app) -> MoonlightNoticeState? {
    guard let notice = moonlightNotice(for: event, words: words) else { return nil }
    let quit = notice.quitHost.map { MoonlightQuitAction(title: words.closeTheAppOn(moonlightHostTitle($0)), hostId: $0.id) }
    return MoonlightNoticeState(
        symbol: moonlightNoticeSymbol(notice.severity),
        tint: moonlightNoticeTint(notice.severity),
        title: notice.title,
        body: notice.body,
        quit: quit
    )
}

func moonlightNoticeSymbol(_ severity: MoonlightNoticeSeverity) -> String {
    switch severity {
    case .info: "info.circle"
    case .success: "checkmark.circle"
    case .warning: "exclamationmark.triangle"
    case .error: "xmark.octagon"
    }
}

func moonlightNoticeTint(_ severity: MoonlightNoticeSeverity) -> Color {
    switch severity {
    case .info: DishTheme.brandGlyph
    case .success: DishTheme.success
    case .warning: DishTheme.warning
    case .error: DishTheme.error
    }
}
