// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// Emulate as: Dish's four pads, or the protocol's four while the pad is
/// bound to a Moonlight host, with the footer saying what Auto sends.
struct ControllerEmulateSection: View {
    let state: ControllerEmulateState
    /// "Updating…" while the PC applies what was just set.
    let updating: String?
    let setEmulateAs: @MainActor (EmulatedPad) -> Void
    /// A pad on a Moonlight host: the protocol's type, nil for Auto.
    let setHostEmulateAs: @MainActor (Int?) -> Void

    var body: some View {
        Section {
            picker
            if let updating {
                BusyRow(text: updating)
            }
        } footer: {
            if let host = state.host {
                Text(host.detail).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
        .listRowBackground(DishTheme.surface)
    }

    @ViewBuilder private var picker: some View {
        if let host = state.host {
            Picker(state.title, selection: Binding(get: { host.selection }, set: { setHostEmulateAs($0) })) {
                ForEach(host.options) { Text($0.label).tag($0.id) }
            }
            .pickerStyle(.menu)
            .foregroundStyle(DishTheme.onSurface)
        } else {
            Picker(state.title, selection: Binding(get: { state.emulateAs }, set: { setEmulateAs($0) })) {
                ForEach(state.options) { Text($0.name).tag($0.pad) }
            }
            .pickerStyle(.menu)
            .foregroundStyle(DishTheme.onSurface)
        }
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
                        VStack(alignment: .leading, spacing: DishSpace.s1) {
                            Text(row.title).foregroundStyle(DishTheme.onSurface)
                            if let status = row.status {
                                Text(status.text)
                                    .font(DishFont.detail)
                                    .foregroundStyle(status.color)
                            }
                        }
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

/// Dead zones ›: the row that pushes the page.
struct ControllerDeadZonesSection: View {
    let title: String
    let open: @MainActor () -> Void

    var body: some View {
        Section {
            Button(action: open) {
                HStack(spacing: DishSpace.s4) {
                    Text(title).foregroundStyle(DishTheme.onSurface)
                    Spacer()
                    Image(systemName: DishSymbol.disclosure).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                }
                .contentShape(Rectangle())
            }
        }
        .listRowBackground(DishTheme.surface)
    }
}
