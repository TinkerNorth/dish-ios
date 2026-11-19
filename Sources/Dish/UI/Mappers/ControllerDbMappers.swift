// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation

/// A verification as its chip shows it.
struct VerificationChipState: Equatable {
    let text: String
    let tone: ChipTone
}

/// One known issue: its title and body in the database's words.
struct ControllerIssueState: Equatable, Identifiable {
    let id: String
    let title: String
    let body: String
}

/// CONTROLLER DATABASE on a controller's page: the record's name and id,
/// its verification as a chip, and the issues it shows on this device.
struct ControllerRecordState: Equatable {
    let title: String
    let lines: [FactLine]
    /// Nil for a pad the database does not know.
    let chip: VerificationChipState?
    let issues: [ControllerIssueState]
}

/// The record section for a pad Dish reads itself; nil for a pad
/// GameController reads, which names no ids to look up, and for the
/// on-screen controller.
func controllerRecordState(_ controller: ControllerFact, strings: ControllerStrings, words: L10n = .app) -> ControllerRecordState? {
    guard readsItsOwnIds(controller.source) else { return nil }
    let lines = recordLines(controller, strings: strings, words: words)
    guard let record = controller.record else {
        return ControllerRecordState(title: words.controllerDatabase, lines: lines, chip: nil, issues: [])
    }
    return ControllerRecordState(
        title: words.controllerDatabase,
        lines: lines,
        chip: verificationChip(record.verification, words: words),
        issues: issueStates(record.issues, strings: strings, words: words)
    )
}

/// Diagnostics' lines for a pad's record: its name from the database, its
/// id and its verification, then each issue by its title; for a pad Dish
/// reads whose ids the database lacks, that it lacks them. A pad
/// GameController reads has no line.
func recordLines(_ controller: ControllerFact, strings: ControllerStrings, words: L10n = .app) -> [FactLine] {
    guard readsItsOwnIds(controller.source) else { return [] }
    guard let record = controller.record else { return [FactLine(key: words.record, value: words.notInTheDatabase)] }
    let locale = words.databaseLocale
    let name = strings.controllerName(record.id, locale: locale).map { [FactLine(key: words.recordName, value: $0)] } ?? []
    return name + [
        FactLine(key: words.record, value: record.id),
        FactLine(key: words.verification, value: verificationText(record.verification, words: words))
    ]
}

/// Diagnostics' lines for a pad's issues, each its title over its body.
func issueLines(_ controller: ControllerFact, strings: ControllerStrings, words: L10n = .app) -> [FactLine] {
    let issues = issueStates(controller.record?.issues ?? [], strings: strings, words: words)
    return issues.map { FactLine(key: $0.title, value: $0.body) }
}

/// Only Dish's own Bluetooth reader knows a pad's ids.
private func readsItsOwnIds(_ source: PadSource?) -> Bool {
    switch source {
    case .bluetooth: true
    case .gameController, nil: false
    }
}

/// An issue the strings have no title for reads as a known issue under its id.
private func issueStates(_ issues: [ControllerIssue], strings: ControllerStrings, words: L10n) -> [ControllerIssueState] {
    let locale = words.databaseLocale
    return issues.map { issue in
        ControllerIssueState(
            id: issue.id,
            title: strings.issueTitle(issue.id, locale: locale) ?? words.knownIssue,
            body: strings.issueBody(issue.id, locale: locale) ?? issue.id
        )
    }
}

func verificationText(_ verification: ControllerVerification, words: L10n = .app) -> String {
    switch verification {
    case .verified: words.verified
    case .imported: words.imported
    case .crowd: words.reportedByPlayers
    case .guessed: words.layoutGuessed
    case .flagged: words.problemsReported
    }
}

/// Verified reads well, imported and the players' word plainly, a guess and
/// reported problems as a caveat.
func verificationChip(_ verification: ControllerVerification, words: L10n = .app) -> VerificationChipState {
    let tone: ChipTone = switch verification {
    case .verified: .success
    case .imported, .crowd: .primary
    case .guessed, .flagged: .warning
    }
    return VerificationChipState(text: verificationText(verification, words: words), tone: tone)
}

// MARK: - The data, in Settings and Diagnostics

/// "Version 3, downloaded".
func databaseVersionText(_ status: ControllerDbStatus, words: L10n = .app) -> String {
    switch status.source {
    case .bundled: words.databaseVersionBuiltIn(status.activeVersion)
    case .cache: words.databaseVersionDownloaded(status.activeVersion)
    }
}

/// How the last check ended; the switch off reads off, whatever it said.
func lastCheckText(_ status: ControllerDbStatus, words: L10n = .app) -> String {
    guard status.checksEnabled else { return words.checkOff }
    guard let result = status.lastCheckResult else { return words.notCheckedYet }
    return checkResultText(result, words: words)
}

func checkResultText(_ result: ControllerDbCheckResult, words: L10n = .app) -> String {
    switch result {
    case .upToDate: words.checkUpToDate
    case .updated: words.checkUpdated
    case .offline: words.checkOffline
    case .invalid: words.checkInvalid
    case .off: words.checkOff
    }
}

/// Diagnostics' lines: the set in force and where it came from, the copy
/// the app was built with, and when the last check ran and how it ended.
func controllerDbLines(
    _ status: ControllerDbStatus,
    locale: Locale = .current,
    timeZone: TimeZone = .current,
    words: L10n = .app
) -> [FactLine] {
    [
        FactLine(key: words.controllerDatabase, value: databaseVersionText(status, words: words)),
        FactLine(key: words.builtInVersion, value: words.protocolTag(status.bundledVersion)),
        FactLine(key: words.lastCheck, value: lastCheckLine(status, locale: locale, timeZone: timeZone, words: words))
    ]
}

/// The result, then the moment in the locale's medium date and short time.
private func lastCheckLine(_ status: ControllerDbStatus, locale: Locale, timeZone: TimeZone, words: L10n) -> String {
    let result = lastCheckText(status, words: words)
    guard let atMs = status.lastCheckAtMs else { return result }
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return dotted(result, formatter.string(from: Date(timeIntervalSince1970: Double(atMs) / 1000)))
}

// MARK: - Settings

/// CONTROLLER DATABASE: the switch in the privacy policy's words with the
/// set in force and the last check under it, Check now, and what the check
/// fetches. Check now waits while a check runs, and is not offered while
/// the switch is off, since nothing may leave the device then.
struct ControllerDbSectionState: Equatable {
    let title: String
    let toggleTitle: String
    let isOn: Bool
    let line: String
    let checkNow: String
    let canCheckNow: Bool
    let footer: String
}

func controllerDbSection(_ status: ControllerDbStatus, words: L10n = .app) -> ControllerDbSectionState {
    let canCheck = status.checksEnabled && !status.checking
    return ControllerDbSectionState(
        title: words.controllerDatabase,
        toggleTitle: words.checkForControllerUpdatesAutomatically,
        isOn: status.checksEnabled,
        line: dotted(databaseVersionText(status, words: words), lastCheckText(status, words: words)),
        checkNow: status.checking ? words.checking : words.checkNow,
        canCheckNow: canCheck,
        footer: words.controllerDatabaseFooter
    )
}
