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
                    StatusMarkView(mark: state.mark)
                    Text(state.line).font(DishFont.monoDetail).foregroundStyle(DishTheme.muted)
                }
            }
        }
        .padding(.vertical, DishSpace.s4)
        .accessibilityElement(children: .combine)
    }
}

/// BINDING › Destination: the PC the pad sends to beside its mark, or Not
/// bound, which opens the menu of the active PCs to bind to, or Find a PC
/// when none is up; the apply inline while one runs or just ended;
/// Updating while the PC applies the pad's settings; the footer that says
/// what to do on the Connections tab when nothing can be picked.
struct ControllerBindingSection: View {
    let state: ControllerBindingState
    let apply: ApplyRowState?
    let updating: String?
    /// Bind to the PC, by its connection id; Try again binds to the same one.
    let bind: @MainActor (String) -> Void
    /// Nothing to bind to: the Connections tab.
    let findPC: @MainActor () -> Void

    var body: some View {
        Section {
            picker
            if let apply {
                ApplyRow(state: apply, retry: bind)
            }
            if let updating {
                BusyRow(text: updating)
            }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        } footer: {
            if let hint = state.hint {
                Text(hint).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
        .listRowBackground(DishTheme.surface)
    }

    /// The destination row opens the active PCs as a menu, the current one
    /// checked; with none up, the row stands alone over Find a PC.
    @ViewBuilder private var picker: some View {
        switch state.picker {
        case let .choices(choices):
            Menu {
                ForEach(choices) { choice in
                    BindChoiceButton(choice: choice, bind: bind)
                }
            } label: {
                LabeledContent(state.destinationTitle) {
                    HStack(spacing: DishSpace.s3) {
                        destination
                        Image(systemName: PlaySymbol.emulate).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                    }
                }
                .foregroundStyle(DishTheme.onSurface)
                .contentShape(Rectangle())
            }
        case let .findPC(title):
            LabeledContent(state.destinationTitle) {
                destination
            }
            .foregroundStyle(DishTheme.onSurface)
            RowButton(action: findPC) {
                Label(title, systemImage: RowActionSymbol.pair).font(DishFont.body).foregroundStyle(DishTheme.primary)
            }
        }
    }

    @ViewBuilder private var destination: some View {
        switch state.destination {
        case let .bound(pcName, mark):
            HStack(spacing: DishSpace.s3) {
                StatusMarkView(mark: mark)
                Text(pcName).font(DishFont.mono)
            }
        case let .unbound(note):
            Text(note).foregroundStyle(DishTheme.muted)
        }
    }
}

/// One PC of the menu; the one the pad sends to wears the check.
private struct BindChoiceButton: View {
    let choice: BindChoice
    let bind: @MainActor (String) -> Void

    var body: some View {
        Button {
            bind(choice.id)
        } label: {
            if choice.current {
                Label(choice.name, systemImage: "checkmark")
            } else {
                Text(choice.name)
            }
        }
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

/// Something the PC is doing for the pad right now: the spinner and its word.
struct BusyRow: View {
    let text: String

    var body: some View {
        HStack(spacing: DishSpace.s4) {
            ProgressView().controlSize(.small)
            Text(text).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
    }
}

/// Unbind, alone at the foot of the page, where iOS keeps what takes
/// something away.
struct ControllerUnbindSection: View {
    let item: RowActionItem<ControllerAction>
    let perform: @MainActor (ControllerAction) -> Void

    var body: some View {
        Section {
            RowButton { perform(item.action) } label: {
                Text(item.title).font(DishFont.body).foregroundStyle(DishTheme.error)
            }
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// TELEMETRY: the rates the pad's streams run at.
struct ControllerTelemetrySection: View {
    let state: ControllerTelemetryState

    var body: some View {
        Section {
            ForEach(state.rows) { row in
                LabeledContent(row.label) {
                    Text(row.value).font(DishFont.mono)
                }
                .foregroundStyle(DishTheme.onSurface)
            }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// CONTROLLER DATABASE: the record's name and id with its verification as
/// a chip, then each known issue, its title over its body.
struct ControllerRecordSection: View {
    let state: ControllerRecordState

    var body: some View {
        Section {
            ForEach(state.lines) { line in
                LabeledContent(line.key) {
                    Text(line.value).font(DishFont.monoDetail).multilineTextAlignment(.trailing).textSelection(.enabled)
                }
                .foregroundStyle(DishTheme.onSurface)
            }
            ForEach(state.issues) { issue in
                VStack(alignment: .leading, spacing: DishSpace.s1) {
                    Text(issue.title).font(DishFont.headline).foregroundStyle(DishTheme.warning)
                    Text(issue.body).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                }
            }
        } header: {
            HStack(spacing: DishSpace.s3) {
                SectionEyebrow(title: state.title, color: DishTheme.muted)
                if let chip = state.chip {
                    Chip(text: chip.text, tone: chip.tone)
                }
            }
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// Emulate as: Dish's four pads, or the protocol's four while the pad is
/// bound to a Moonlight host, with the footer saying what Auto sends.
struct ControllerEmulateSection: View {
    let state: ControllerEmulateState
    let setEmulateAs: @MainActor (EmulatedPad) -> Void
    /// A pad on a Moonlight host: the protocol's type, nil for Auto.
    let setHostEmulateAs: @MainActor (Int?) -> Void

    var body: some View {
        Section {
            picker
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

/// FUNCTIONS: one switch per feature the pad has, a Steam Controller's
/// trackpads, and why two are missing.
struct ControllerFunctionsSection: View {
    let state: ControllerFunctionsState
    let footnote: String
    let setFeature: @MainActor (SlotSwitch, Bool) -> Void
    let setTrackpads: @MainActor (TouchpadPick) -> Void

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
            if let trackpads = state.trackpads {
                Picker(selection: Binding(get: { trackpads.selection }, set: { setTrackpads($0) })) {
                    ForEach(trackpads.options) { Text($0.title).tag($0.pick) }
                } label: {
                    Label {
                        Text(trackpads.title).foregroundStyle(DishTheme.onSurface)
                    } icon: {
                        Image(systemName: trackpads.symbol).foregroundStyle(DishTheme.primary)
                    }
                }
                .pickerStyle(.menu)
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
            RowButton(action: open) {
                HStack(spacing: DishSpace.s4) {
                    Text(title).foregroundStyle(DishTheme.onSurface)
                    Spacer()
                    Image(systemName: DishSymbol.disclosure).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                }
            }
        }
        .listRowBackground(DishTheme.surface)
    }
}
