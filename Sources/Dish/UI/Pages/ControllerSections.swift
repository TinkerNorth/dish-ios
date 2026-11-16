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
/// bound; the apply inline while one runs or just ended; Updating while
/// the PC applies the pad's settings; with no PC paired, the footer that
/// says where to pair one.
struct ControllerBindingSection: View {
    let state: ControllerBindingState
    let apply: ApplyRowState?
    let updating: String?
    /// Try again, with the PC the bind is to reach again.
    let retry: @MainActor (String) -> Void

    var body: some View {
        Section {
            LabeledContent(state.destinationTitle) {
                destination
            }
            .foregroundStyle(DishTheme.onSurface)
            if let apply {
                ApplyRow(state: apply, retry: retry)
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
            Button(item.title, role: .destructive) { perform(item.action) }
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
