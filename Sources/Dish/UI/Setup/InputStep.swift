// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// B2, Input · 1 of 3: a pad iOS already sees comes first with its Use
/// button, then the three ways in. A pick moves the walk on.
struct InputStep: View {
    let state: InputStepState

    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            SetupHeading(title: state.title, detail: state.body)
            if let found = state.found {
                Section {
                    ForEach(found.pads) { pad in
                        SetupPadRowView(row: pad, pick: model.pickSetupInput)
                    }
                } header: {
                    SectionEyebrow(title: found.title, color: DishTheme.primary)
                }
            }
            Section {
                ForEach(state.choices) { choice in
                    SetupChoiceRowView(row: choice, pick: model.pickSetupInput)
                }
            } header: {
                SectionEyebrow(title: state.chooseTitle, color: DishTheme.muted)
            } footer: {
                Text(state.footnote)
                    .font(DishFont.detail)
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct SetupPadRowView: View {
    let row: SetupPadRow
    let pick: (InputKind) -> Void

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            SetupGlyphTile(symbol: row.symbol)
            SetupRowText(title: row.name, detail: row.detail)
            Spacer(minLength: DishSpace.s4)
            Button(row.use, action: use)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
    }

    private func use() {
        pick(row.pick)
    }
}

private struct SetupChoiceRowView: View {
    let row: SetupChoiceRow
    let pick: (InputKind) -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: DishSpace.s6) {
                SetupGlyphTile(symbol: row.symbol)
                VStack(alignment: .leading, spacing: DishSpace.s1) {
                    HStack(spacing: DishSpace.s4) {
                        Text(row.title)
                            .font(DishFont.body)
                            .foregroundStyle(DishTheme.onSurface)
                        if let chip = row.chip {
                            Chip(text: chip.text, tone: chip.tone)
                        }
                    }
                    Text(row.body)
                        .font(DishFont.detail)
                        .foregroundStyle(DishTheme.muted)
                }
                Spacer(minLength: DishSpace.s4)
                Image(systemName: DishSymbol.disclosure)
                    .font(DishFont.detail)
                    .foregroundStyle(DishTheme.muted)
            }
        }
    }

    private func choose() {
        pick(row.pick)
    }
}

#Preview("Nothing seen") {
    InputStep(state: inputStepState(PreviewSetup.nothingSeen))
        .environment(PreviewSetup.emptyModel())
}

#Preview("A pad seen") {
    InputStep(state: inputStepState(PreviewSetup.padsAndPCs))
        .environment(PreviewSetup.emptyModel())
}
