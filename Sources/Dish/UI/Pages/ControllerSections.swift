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

/// BINDING › Destination with Unbind, or Bind to a paired PC; the apply
/// inline while one runs or just ended; Emulate as.
struct ControllerBindingSection: View {
    let state: ControllerBindingState
    let apply: ApplyRowState?
    let actions: ControllerActions

    var body: some View {
        Section {
            destination
            if let apply {
                ApplyRow(state: apply, retry: actions.bind)
            }
            emulate
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }

    /// Dish's four pads, or the protocol's four while the pad is on a Moonlight host.
    @ViewBuilder private var emulate: some View {
        if let host = state.hostEmulate {
            Picker(state.emulateTitle, selection: Binding(get: { host.selection }, set: { actions.setHostEmulateAs($0) })) {
                ForEach(host.options) { Text($0.label).tag($0.id) }
            }
            .pickerStyle(.menu)
            .foregroundStyle(DishTheme.onSurface)
            Text(host.detail).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        } else {
            Picker(state.emulateTitle, selection: Binding(get: { state.emulateAs }, set: { actions.setEmulateAs($0) })) {
                ForEach(state.emulateOptions) { Text($0.name).tag($0.pad) }
            }
            .pickerStyle(.menu)
            .foregroundStyle(DishTheme.onSurface)
        }
    }

    @ViewBuilder private var destination: some View {
        switch state.destination {
        case let .bound(pcName, dot, unbind):
            LabeledContent(state.destinationTitle) {
                HStack(spacing: DishSpace.s3) {
                    StatusDot(color: dot)
                    Text(pcName).font(DishFont.mono)
                }
            }
            .foregroundStyle(DishTheme.onSurface)
            Button(unbind, role: .destructive, action: actions.unbind)
        case let .unbound(bindTo, choices, hint):
            Menu {
                ForEach(choices) { choice in
                    Button(choice.name) { actions.bind(choice.id) }
                }
            } label: {
                BindToRow(title: state.destinationTitle, bindTo: bindTo)
            }
            .disabled(choices.isEmpty)
            if let hint {
                Text(hint).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
    }
}

/// Destination · Bind to ›, the menu's label.
private struct BindToRow: View {
    let title: String
    let bindTo: String

    var body: some View {
        HStack(spacing: DishSpace.s4) {
            Text(title).foregroundStyle(DishTheme.onSurface)
            Spacer()
            Text(bindTo).font(DishFont.body).foregroundStyle(DishTheme.primary)
            Image(systemName: DishSymbol.disclosure).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
        .contentShape(Rectangle())
    }
}

/// Where the bind stands, with Try again once it failed.
private struct ApplyRow: View {
    let state: ApplyRowState
    let retry: @MainActor (String) -> Void

    var body: some View {
        HStack(spacing: DishSpace.s4) {
            if state.spinner {
                ProgressView().controlSize(.small)
            }
            Text(state.text).font(DishFont.detail).foregroundStyle(state.color)
            Spacer(minLength: DishSpace.s4)
            if let title = state.retry {
                Button(title) { retry(state.connectionId) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .font(DishFont.detail)
            }
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
