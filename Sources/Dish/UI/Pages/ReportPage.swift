// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// Diagnostics › Report a problem, and Ask a question: the category, the
/// person's own words, the controller it concerns, what the file will hold
/// in plain words, Preview file and Continue in Mail.
struct ReportPage: View {
    let start: ReportStart

    @Environment(AppModel.self) private var model
    @Environment(\.appVersion) private var appVersion

    var body: some View {
        ReportPageBody(
            start: start,
            facts: model.reportFacts,
            appVersion: appVersion,
            preview: preview,
            send: send
        )
    }

    private func preview(_ draft: ReportDraft) {
        model.previewReport(draft)
    }

    private func send(_ draft: ReportDraft, _ mail: ReportMail) {
        model.continueReport(draft, mail: mail)
    }
}

/// The form over its facts. The draft is the page's own, starting on the
/// category the entry names and the first pad connected now.
struct ReportPageBody: View {
    let start: ReportStart
    let facts: ReportFacts
    let appVersion: String
    let preview: @MainActor (ReportDraft) -> Void
    let send: @MainActor (ReportDraft, ReportMail) -> Void

    @State private var draft: ReportDraftState

    init(
        start: ReportStart,
        facts: ReportFacts,
        appVersion: String,
        preview: @escaping @MainActor (ReportDraft) -> Void,
        send: @escaping @MainActor (ReportDraft, ReportMail) -> Void
    ) {
        self.start = start
        self.facts = facts
        self.appVersion = appVersion
        self.preview = preview
        self.send = send
        _draft = State(initialValue: initialReportDraft(start, facts: facts))
    }

    private var state: ReportPageState {
        reportPageState(start: start, facts: facts, draft: draft, appVersion: appVersion)
    }

    var body: some View {
        let state = state
        List {
            Section {
                Picker(state.categoryLabel, selection: $draft.category) {
                    ForEach(state.categories) { choice in
                        Text(choice.label).tag(choice.value)
                    }
                }
                .pickerStyle(.menu)
            }
            .listRowBackground(DishTheme.surface)
            Section {
                TextField(state.prompt, text: $draft.text, axis: .vertical)
                    .font(DishFont.body)
                    .foregroundStyle(DishTheme.onSurface)
                    .lineLimit(4 ... 12)
            } header: {
                SectionEyebrow(title: state.prompt, color: DishTheme.muted)
            }
            .listRowBackground(DishTheme.surface)
            Section {
                Picker(state.controllerLabel, selection: $draft.controllerId) {
                    ForEach(state.controllers) { choice in
                        Text(choice.label).tag(choice.value)
                    }
                }
                .pickerStyle(.menu)
            }
            .listRowBackground(DishTheme.surface)
            ReportHoldsSection(state: state)
            ReportActionsSection(state: state, preview: previewFile, send: continueInMail)
            if let file = state.file {
                Section {
                    Text(file)
                        .font(DishFont.monoDetail)
                        .foregroundStyle(DishTheme.onSurface)
                        .textSelection(.enabled)
                }
                .listRowBackground(DishTheme.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func previewFile() {
        guard let ready = state.draft else { return }
        preview(ready)
    }

    private func continueInMail() {
        guard let ready = state.draft, let mail = state.mail else { return }
        send(ready, mail)
    }
}

/// What the file will hold, in plain words, and what it never holds.
private struct ReportHoldsSection: View {
    let state: ReportPageState

    var body: some View {
        Section {
            ForEach(state.holds, id: \.self) { item in
                Text(item).font(DishFont.detail).foregroundStyle(DishTheme.onSurface)
            }
        } header: {
            SectionEyebrow(title: state.holdsTitle, color: DishTheme.muted)
        } footer: {
            SettingsFooter(text: state.never)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// Preview file and Continue in Mail, and the word on the file in the works.
private struct ReportActionsSection: View {
    let state: ReportPageState
    let preview: @MainActor () -> Void
    let send: @MainActor () -> Void

    var body: some View {
        Section {
            RowButton(action: preview) {
                Text(state.preview).font(DishFont.body).foregroundStyle(DishTheme.primary)
            }
            .disabled(!state.actionsEnabled)
            RowButton(action: send) {
                Text(state.send).font(DishFont.body).foregroundStyle(DishTheme.primary)
            }
            .disabled(!state.actionsEnabled)
        } footer: {
            if let status = state.status {
                SettingsFooter(text: status)
            }
        }
        .listRowBackground(DishTheme.surface)
    }
}

#Preview("Report a problem") {
    NavigationStack {
        ReportPageBody(start: .problem, facts: previewReportFacts(.idle), appVersion: "1.1.0", preview: { _ in }, send: { _, _ in })
    }
}

#Preview("Ask a question") {
    NavigationStack {
        ReportPageBody(start: .question, facts: previewReportFacts(.idle), appVersion: "1.1.0", preview: { _ in }, send: { _, _ in })
    }
}

#Preview("Preparing") {
    let draft = ReportDraft(category: .question, text: "", controllerId: "pad")
    NavigationStack {
        ReportPageBody(
            start: .question,
            facts: previewReportFacts(.preparing(draft)),
            appVersion: "1.1.0",
            preview: { _ in },
            send: { _, _ in }
        )
    }
}

/// A pad connected, the controller data built in, and the preparation given.
private func previewReportFacts(_ preparation: ReportPreparation) -> ReportFacts {
    let pad = ControllerFact(
        id: "pad",
        name: "DualSense Wireless Controller",
        link: .usbC,
        batteryPercent: 84,
        destination: nil,
        source: .gameController(category: "DualSense")
    )
    return ReportFacts(controllers: [pad], localNetwork: .allowed, controllerDb: .none, preparation: preparation)
}
