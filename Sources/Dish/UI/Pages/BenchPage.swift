// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What the bench's controls do: each one an intent.
struct BenchActions {
    let run: @MainActor (BenchTest) -> Void
    let answer: @MainActor (Bool) -> Void

    /// Controls that do nothing, for a preview.
    @MainActor static let preview = BenchActions(run: { _ in }, answer: { _ in })
}

/// Diagnostics › a controller › Controller tests: each test the pad's path
/// carries, run from this device alone, and "Did it work?" after each.
struct BenchPage: View {
    let id: String

    @Environment(AppModel.self) private var model

    var body: some View {
        BenchPageBody(state: benchPageState(id: id, facts: model.benchFacts), actions: BenchActions(run: run, answer: answer))
    }

    private func run(_ test: BenchTest) {
        model.runBenchTest(test, slotId: id)
    }

    private func answer(_ worked: Bool) {
        model.answerBenchTest(slotId: id, worked: worked)
    }
}

/// The page over its state, so a preview can draw every state.
struct BenchPageBody: View {
    let state: BenchPageState
    let actions: BenchActions

    var body: some View {
        List {
            switch state.content {
            case let .pad(card):
                BenchCard(card: card, actions: actions)
            case let .gone(message):
                ContentUnavailableView(state.title, systemImage: "gamecontroller", description: Text(message))
                    .listRowBackground(EmptyView())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationSubtitle(state.subtitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The intro, a section per item the path carries, or the word for none,
/// then "Did it work?".
private struct BenchCard: View {
    let card: BenchCardState
    let actions: BenchActions

    var body: some View {
        Section {
            if let nothing = card.nothing {
                Text(nothing).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        } footer: {
            SettingsFooter(text: card.intro)
        }
        .listRowBackground(DishTheme.surface)
        ForEach(card.sections) { section in
            BenchItemSection(state: section, run: actions.run)
        }
        BenchAnswersSection(state: card.answers, answer: actions.answer)
    }
}

/// One item: a row per test, the stick tests' line, and what the tests do.
private struct BenchItemSection: View {
    let state: BenchSectionState
    let run: @MainActor (BenchTest) -> Void

    var body: some View {
        Section {
            ForEach(state.rows) { row in
                BenchTestRow(row: row, run: run)
            }
            if let status = state.status {
                Text(status).font(DishFont.monoDetail).foregroundStyle(DishTheme.onSurface).textSelection(.enabled)
            }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        } footer: {
            SettingsFooter(text: state.footer)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// One test: its name, the spinner while it runs, waiting while another does.
private struct BenchTestRow: View {
    let row: BenchTestRowState
    let run: @MainActor (BenchTest) -> Void

    var body: some View {
        RowButton(action: start) {
            HStack(spacing: DishSpace.s4) {
                Text(row.label).font(DishFont.body).foregroundStyle(DishTheme.primary)
                Spacer()
                if row.running {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .disabled(!row.enabled)
    }

    private func start() {
        run(row.id)
    }
}

/// The question once a test ends, with its two answers, and the answers
/// kept, newest first; the hint before any.
private struct BenchAnswersSection: View {
    let state: BenchAnswersState
    let answer: @MainActor (Bool) -> Void

    var body: some View {
        Section {
            if let question = state.question {
                Text(question).font(DishFont.headline).foregroundStyle(DishTheme.onSurface)
                RowButton(action: worked) {
                    Text(state.worked).font(DishFont.body).foregroundStyle(DishTheme.primary)
                }
                RowButton(action: didNotWork) {
                    Text(state.didNotWork).font(DishFont.body).foregroundStyle(DishTheme.primary)
                }
            }
            ForEach(state.answers) { line in
                Text(line.text).font(DishFont.monoDetail).foregroundStyle(DishTheme.muted)
            }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        } footer: {
            if let hint = state.hint {
                SettingsFooter(text: hint)
            }
        }
        .listRowBackground(DishTheme.surface)
    }

    private func worked() {
        answer(true)
    }

    private func didNotWork() {
        answer(false)
    }
}

#Preview("DualSense") {
    let pad = ControllerFact(id: "ds", name: "DualSense Wireless Controller", link: .usbC, batteryPercent: 84, destination: nil)
    let reach: BenchReach = [.strongMotor, .weakMotor, .lightbar, .playerLeds, .adaptiveTriggers, .sticks]
    let state = benchPageState(id: "ds", facts: BenchFacts(controllers: [pad], reach: ["ds": reach]))
    NavigationStack {
        BenchPageBody(state: state, actions: .preview)
    }
}

#Preview("A test running") {
    let pad = ControllerFact(id: "xbox", name: "Xbox Wireless Controller", link: .bluetooth, batteryPercent: 60, destination: nil)
    let reach: BenchReach = [.strongMotor, .weakMotor, .leftTriggerMotor, .rightTriggerMotor, .sticks]
    var bench = BenchState()
    bench.running["xbox"] = .stickRange
    bench.stickSecondsLeft["xbox"] = 6
    let state = benchPageState(id: "xbox", facts: BenchFacts(controllers: [pad], reach: ["xbox": reach], bench: bench))
    return NavigationStack {
        BenchPageBody(state: state, actions: .preview)
    }
}

#Preview("Did it work?") {
    let pad = ControllerFact(id: "ds", name: "DualSense Wireless Controller", link: .usbC, batteryPercent: 84, destination: nil)
    var bench = BenchState()
    bench.asking["ds"] = BenchQuestion(test: .lightbarCycle, endedAtMs: 1)
    bench.answers["ds"] = [BenchOutcome(test: .rumbleWeak, result: .worked, atMs: 0)]
    let state = benchPageState(id: "ds", facts: BenchFacts(controllers: [pad], reach: ["ds": [.weakMotor, .lightbar]], bench: bench))
    return NavigationStack {
        BenchPageBody(state: state, actions: .preview)
    }
}

#Preview("Nothing to test") {
    let onScreen = ControllerFact(id: onScreenSlotId, name: "", link: .onScreen, batteryPercent: nil, destination: nil)
    let state = benchPageState(id: onScreenSlotId, facts: BenchFacts(controllers: [onScreen], reach: [:]))
    NavigationStack {
        BenchPageBody(state: state, actions: .preview)
    }
}

#Preview("Gone") {
    NavigationStack {
        BenchPageBody(state: benchPageState(id: "ds", facts: BenchFacts(controllers: [], reach: [:])), actions: .preview)
    }
}
