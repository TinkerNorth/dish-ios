// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import Foundation

/// A section of cards under its eyebrow.
struct DiagnosticsCardsState: Equatable {
    let title: String
    let cards: DiagnosticsCards
}

/// A section of plain lines under its eyebrow.
struct DiagnosticsSectionState: Equatable {
    let title: String
    let lines: [FactLine]
}

struct DiagnosticsEventLine: Equatable, Identifiable {
    let id: Int
    let text: String
}

enum DiagnosticsEventsContent: Equatable {
    case empty(String)
    case lines([DiagnosticsEventLine])
}

/// The recorder's section: the newest lines, newest first, and the note
/// under them.
struct DiagnosticsEventsState: Equatable {
    let title: String
    let content: DiagnosticsEventsContent
    let note: String
}

/// Everything Diagnostics draws, and the transcript Copy and Share hand over.
struct DiagnosticsPageState: Equatable {
    let title: String
    let intro: String
    let app: DiagnosticsSectionState
    let hosts: DiagnosticsCardsState
    let pads: DiagnosticsCardsState
    /// Nil in a plain build, which counts no lock.
    let locks: DiagnosticsSectionState?
    let events: DiagnosticsEventsState
    let copy: String
    let copied: String
    let transcript: String
}

func diagnosticsPageState(
    facts: ShellFacts,
    appVersion: String,
    locale: Locale = .current,
    timeZone: TimeZone = .current,
    words: L10n = .app
) -> DiagnosticsPageState {
    let app = DiagnosticsSectionState(
        title: words.appName,
        lines: appLines(appVersion: appVersion, localNetwork: facts.localNetwork, words: words)
    )
    let hosts = DiagnosticsCardsState(
        title: words.connections,
        cards: cards(facts.diagnostics.hosts.map { hostCard($0, locale: locale, words: words) }, empty: words.noPCsForDiagnostics)
    )
    let pads = DiagnosticsCardsState(
        title: words.controllers,
        cards: cards(facts.diagnostics.pads.map { padCard($0, words: words) }, empty: words.noControllersConnected)
    )
    let locks = facts.diagnostics.locks.map { DiagnosticsSectionState(title: words.lockStatistics, lines: lockLines($0, words: words)) }
    let events = eventsState(facts.diagnosticsEvents, locale: locale, timeZone: timeZone, words: words)
    let log = eventsTranscript(facts.diagnosticsEvents, locale: locale, timeZone: timeZone, words: words)
    let blocks: [String?] = [sectionText(app), cardsText(hosts), cardsText(pads), locks.map(sectionText)]
    return DiagnosticsPageState(
        title: pageTitle(.diagnostics, words: words),
        intro: words.diagnosticsDetail,
        app: app,
        hosts: hosts,
        pads: pads,
        locks: locks,
        events: events,
        copy: words.copy,
        copied: words.copied,
        transcript: transcript(blocks: blocks, log: log, events: events)
    )
}

private func cards(_ cards: [DiagnosticsCardState], empty: String) -> DiagnosticsCards {
    cards.isEmpty ? .empty(empty) : .cards(cards)
}

private func eventsState(_ events: [DiagnosticsEvent], locale: Locale, timeZone: TimeZone, words: L10n) -> DiagnosticsEventsState {
    let lines = recentEvents(events).map { event in
        DiagnosticsEventLine(id: event.id, text: eventLine(event, locale: locale, timeZone: timeZone, words: words))
    }
    return DiagnosticsEventsState(
        title: words.events,
        content: lines.isEmpty ? .empty(words.noEventsYet) : .lines(lines),
        note: words.eventsNote
    )
}

// MARK: - The transcript

/// The page as text, section by section with a blank line between, for the
/// pasteboard and the share sheet; the log goes whole, oldest first.
private func transcript(blocks: [String?], log: String, events: DiagnosticsEventsState) -> String {
    let logText = log.isEmpty ? emptyEventsText(events) : log
    let eventsBlock = [events.title, logText].joined(separator: "\n")
    return (blocks.compactMap(\.self) + [eventsBlock]).joined(separator: "\n\n")
}

private func emptyEventsText(_ events: DiagnosticsEventsState) -> String {
    switch events.content {
    case let .empty(note): note
    case .lines: ""
    }
}

private func sectionText(_ section: DiagnosticsSectionState) -> String {
    ([section.title] + section.lines.map(lineText)).joined(separator: "\n")
}

private func cardsText(_ section: DiagnosticsCardsState) -> String {
    switch section.cards {
    case let .empty(note): [section.title, note].joined(separator: "\n")
    case let .cards(cards): ([section.title] + cards.map(cardText)).joined(separator: "\n")
    }
}

private func cardText(_ card: DiagnosticsCardState) -> String {
    let headline = ([card.title] + [card.chip].compactMap(\.self)).joined(separator: lineSeparator)
    return ([headline] + card.lines.map(lineText)).joined(separator: "\n")
}

private func lineText(_ line: FactLine) -> String {
    "\(line.key): \(line.value)"
}
