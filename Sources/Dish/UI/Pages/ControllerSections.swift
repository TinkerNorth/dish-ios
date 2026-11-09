// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The card at the head of a controller's page: its glyph, its name, and
/// its link, family and battery beside a dot.
struct ControllerStatusCard: View {
    let state: ControllerStatusState

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            RowGlyph(symbol: state.symbol)
            VStack(alignment: .leading, spacing: DishSpace.s1) {
                Text(state.title).font(DishFont.headline).foregroundStyle(DishTheme.onSurface)
                HStack(spacing: DishSpace.s3) {
                    StatusDot(color: state.dot)
                    Text(state.line).font(DishFont.monoDetail).foregroundStyle(DishTheme.muted)
                }
            }
        }
        .padding(.vertical, DishSpace.s4)
        .accessibilityElement(children: .combine)
    }
}

/// BINDING › Destination, Emulate as.
struct ControllerBindingSection: View {
    let state: ControllerBindingState
    let setEmulateAs: @MainActor (EmulatedPad) -> Void

    var body: some View {
        Section {
            LabeledContent(state.destinationTitle) {
                HStack(spacing: DishSpace.s4) {
                    Text(state.destination).font(DishFont.mono)
                    Image(systemName: DishSymbol.disclosure).font(DishFont.detail)
                }
                .foregroundStyle(DishTheme.muted)
            }
            .foregroundStyle(DishTheme.onSurface)
            .disabled(!state.destinationEnabled)
            Picker(state.emulateTitle, selection: Binding(get: { state.emulateAs }, set: { setEmulateAs($0) })) {
                ForEach(state.emulateOptions) { Text($0.name).tag($0.pad) }
            }
            .pickerStyle(.menu)
            .foregroundStyle(DishTheme.onSurface)
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// FUNCTIONS: one switch per feature the pad has, and why two are missing.
struct ControllerFunctionsSection: View {
    let state: ControllerFunctionsState
    let footnote: String
    let setFeature: @MainActor (SlotSwitch, Bool) -> Void

    var body: some View {
        Section {
            ForEach(state.rows) { row in
                Toggle(isOn: Binding(get: { row.isOn }, set: { setFeature(row.feature, $0) })) {
                    Label {
                        Text(row.title).foregroundStyle(DishTheme.onSurface)
                    } icon: {
                        Image(systemName: row.symbol).foregroundStyle(DishTheme.primary)
                    }
                }
                .tint(DishTheme.success)
            }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        } footer: {
            Text(footnote).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }
}
