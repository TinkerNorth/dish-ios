// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation

/// What the person has filled in so far: the page's own draft.
struct ReportDraftState: Equatable {
    var category: ReportCategory?
    var text: String
    var controllerId: String?
}

/// One choice in a picker: its value and its words.
struct ReportChoice<Value: Hashable>: Equatable, Identifiable {
    let value: Value
    let label: String

    var id: Value {
        value
    }
}

/// Everything Report a problem draws, and the mail it hands over.
struct ReportPageState: Equatable {
    let title: String
    let categoryLabel: String
    /// "Choose one" first while nothing is picked, then the six.
    let categories: [ReportChoice<ReportCategory?>]
    let prompt: String
    let controllerLabel: String
    /// "None" first, then every controller by its name.
    let controllers: [ReportChoice<String?>]
    let holdsTitle: String
    let holds: [String]
    let never: String
    let preview: String
    let send: String
    /// The draft as the engine takes it; nil until a category is picked.
    let draft: ReportDraft?
    /// Both actions wait for a category and for the file in the works.
    let actionsEnabled: Bool
    /// What is under way, or why the last file failed; nil otherwise.
    let status: String?
    /// The file as it will be sent, once previewed for this very draft.
    let file: String?
    let mail: ReportMail?
}

/// A problem starts with no category picked, a question on its own; the
/// controller is the first pad connected now, else none.
func initialReportDraft(_ start: ReportStart, facts: ReportFacts) -> ReportDraftState {
    let category: ReportCategory? = switch start {
    case .problem: nil
    case .question: .question
    }
    let connected = facts.controllers.first { $0.source != nil }
    return ReportDraftState(category: category, text: "", controllerId: connected?.id)
}

func reportPageState(
    start: ReportStart,
    facts: ReportFacts,
    draft: ReportDraftState,
    appVersion: String,
    locale: Locale = .current,
    timeZone: TimeZone = .current,
    words: L10n = .app
) -> ReportPageState {
    let ready = draft.category.map { ReportDraft(category: $0, text: draft.text, controllerId: draft.controllerId) }
    let busy = isPreparing(facts.preparation)
    let summary = reportSummary(facts, appVersion: appVersion, locale: locale, timeZone: timeZone, words: words)
    return ReportPageState(
        title: pageTitle(.report(start), words: words),
        categoryLabel: words.reportCategory,
        categories: categoryChoices(picked: draft.category, words: words),
        prompt: words.reportPrompt,
        controllerLabel: words.controller,
        controllers: [ReportChoice(value: nil, label: words.noController)]
            + facts.controllers.map { ReportChoice(value: $0.id, label: controllerName($0, words: words)) },
        holdsTitle: words.theFileWillHold,
        holds: [
            words.holdsYourWords,
            words.holdsThisDevice,
            words.holdsControllerData,
            words.holdsControllers,
            words.holdsAnswers,
            words.holdsHosts,
            words.holdsEvents
        ],
        never: words.diagnosticsAttachmentNote,
        preview: words.previewFile,
        send: words.continueInMail,
        draft: ready,
        actionsEnabled: ready != nil && !busy,
        status: preparationStatus(facts.preparation, words: words),
        file: previewedFile(facts.preparation, draft: ready),
        mail: ready.map { reportMail($0, summary: summary, words: words) }
    )
}

/// The contract's six in its order; "Choose one" stands first only while
/// nothing is picked, so it can never be picked back.
private func categoryChoices(picked: ReportCategory?, words: L10n) -> [ReportChoice<ReportCategory?>] {
    let six = ReportCategory.allCases.map { ReportChoice<ReportCategory?>(value: $0, label: categoryText($0, words: words)) }
    guard picked == nil else { return six }
    return [ReportChoice(value: nil, label: words.chooseACategory)] + six
}

func categoryText(_ category: ReportCategory, words: L10n = .app) -> String {
    switch category {
    case .notRecognised: words.categoryNotRecognised
    case .noFeedback: words.categoryNoFeedback
    case .connection: words.categoryConnection
    case .audio: words.categoryAudio
    case .other: words.categoryOther
    case .question: words.categoryQuestion
    }
}

private func isPreparing(_ preparation: ReportPreparation) -> Bool {
    switch preparation {
    case .preparing: true
    case .idle, .ready, .failed: false
    }
}

private func preparationStatus(_ preparation: ReportPreparation, words: L10n) -> String? {
    switch preparation {
    case .preparing: words.preparingTheFile
    case .failed: words.fileNotWritten
    case .idle, .ready: nil
    }
}

/// The preview belongs to the draft it was made from: a draft changed since
/// is a file not yet written.
private func previewedFile(_ preparation: ReportPreparation, draft: ReportDraft?) -> String? {
    guard case let .ready(made, prepared) = preparation, made == draft else { return nil }
    return prepared.text
}

// MARK: - The mail

/// The person's words first, then the summary, then what the file never
/// holds; the subject's category in their language.
private func reportMail(_ draft: ReportDraft, summary: String, words: L10n) -> ReportMail {
    let parts = [draft.text, summary, words.diagnosticsAttachmentNote].filter { !$0.isEmpty }
    return ReportMail(category: categoryText(draft.category, words: words), body: parts.joined(separator: "\n\n"))
}

/// The app's section, then each controller by its name and its record. A
/// controller's binding is left out, since it names a PC.
func reportSummary(
    _ facts: ReportFacts,
    appVersion: String,
    locale: Locale = .current,
    timeZone: TimeZone = .current,
    words: L10n = .app
) -> String {
    let app = appLines(appVersion: appVersion, localNetwork: facts.localNetwork, words: words)
        + controllerDbLines(facts.controllerDb.status, locale: locale, timeZone: timeZone, words: words)
    let appBlock = ([words.appName] + app.map(summaryLine)).joined(separator: "\n")
    let pads = facts.controllers.map { controllerBlock($0, strings: facts.controllerDb.strings, words: words) }
    let padsBlock = ([words.controllers] + pads).joined(separator: "\n")
    return [appBlock, padsBlock].joined(separator: "\n\n")
}

private func controllerBlock(_ controller: ControllerFact, strings: ControllerStrings, words: L10n) -> String {
    let lines = recordLines(controller, strings: strings, words: words).map(summaryLine)
    return ([controllerName(controller, words: words)] + lines).joined(separator: "\n")
}

private func summaryLine(_ line: FactLine) -> String {
    "\(line.key): \(line.value)"
}
