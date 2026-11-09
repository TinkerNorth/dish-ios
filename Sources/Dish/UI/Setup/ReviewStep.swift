// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// B6, Binding · 3 of 3: the link from the pad to the PC, Emulate as and
/// Motion, what carries each way, and Bind, which ends the walk.
struct ReviewStep: View {
    let state: ReviewStepState
    /// The cover's Bind: the model binds, the navigation lowers the cover.
    let bind: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            SetupHeading(title: state.title, detail: state.body)
            Section {
                ReviewLinkCard(pad: state.pad, pc: state.pc)
            }
            Section {
                Picker(state.emulateTitle, selection: emulateAs) {
                    ForEach(state.emulateOptions) { option in
                        Text(option.name).tag(option.pad)
                    }
                }
                .pickerStyle(.menu)
                Toggle(state.motionTitle, isOn: motion)
                    .disabled(!state.motionEnabled)
            } footer: {
                Text(state.footnote)
                    .font(DishFont.detail)
            }
            Section {
                HStack(alignment: .top, spacing: DishSpace.s8) {
                    CarryColumnView(column: state.sends)
                    CarryColumnView(column: state.getsBack)
                }
            } header: {
                SectionEyebrow(title: state.carriesTitle, color: DishTheme.muted)
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            SetupBottomBar(title: state.primary, action: bind)
        }
    }

    private var emulateAs: Binding<EmulatedPad> {
        Binding(get: { state.emulateAs }, set: model.setSetupEmulateAs)
    }

    private var motion: Binding<Bool> {
        Binding(get: { state.motion }, set: model.setSetupMotion)
    }
}

/// The pad above the PC, an arrow between: what is about to be linked.
private struct ReviewLinkCard: View {
    let pad: ReviewEndState?
    let pc: ReviewEndState?

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s4) {
            if let pad {
                ReviewEndRow(end: pad, nameFont: DishFont.headline)
            }
            Image(systemName: DishSymbol.linkArrow)
                .font(DishFont.detail)
                .foregroundStyle(DishTheme.primary)
                .frame(width: DishSize.rowGlyph)
                .accessibilityHidden(true)
            if let pc {
                ReviewEndRow(end: pc, nameFont: DishFont.mono)
            }
        }
        .padding(.vertical, DishSpace.s2)
    }
}

private struct ReviewEndRow: View {
    let end: ReviewEndState
    let nameFont: Font

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            SetupGlyphTile(symbol: end.symbol)
            Text(end.name)
                .font(nameFont)
                .foregroundStyle(DishTheme.onSurface)
            Spacer(minLength: DishSpace.s4)
            HStack(spacing: DishSpace.s3) {
                if let dot = end.dot {
                    StatusDot(color: dot)
                }
                if let detail = end.detail {
                    Text(detail)
                        .font(DishFont.detail)
                        .foregroundStyle(DishTheme.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CarryColumnView: View {
    let column: CarryColumn

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s4) {
            Text(column.title)
                .font(DishFont.columnTitle)
                .foregroundStyle(DishTheme.muted)
            ForEach(column.rows) { row in
                HStack(spacing: DishSpace.s4) {
                    Image(systemName: row.symbol)
                        .font(DishFont.columnTitle)
                        .foregroundStyle(row.tint)
                        .frame(width: DishSize.carryMark)
                    Text(row.title)
                        .font(DishFont.body)
                        .foregroundStyle(row.label)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("A seen DualSense to a paired PC") {
    ReviewStep(state: reviewStepState(PreviewSetup.reviewDraft, PreviewSetup.padsAndPCs), bind: {})
        .environment(PreviewSetup.emptyModel())
}
