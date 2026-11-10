// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// One Moonlight host: its glyph, its name in mono, its kind, the trust
/// word with the address and the controllers under a dot, why its session
/// is not up, the app it starts, the PIN card while it pairs, the way out
/// of where it stands, and Forget behind the menu.
struct MoonlightHostRow: View {
    let state: MoonlightHostRowState
    let actions: MoonlightHostsActions

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s4) {
            header
            if let line = state.statusLine {
                Text(line).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
            if let app = state.app {
                MoonlightAppPicker(state: app, pick: pickApp)
            }
            if let pin = state.pin {
                MoonlightPinCard(state: pin, cancel: cancelPairing, newCode: newCode)
            }
            actionRow
        }
        .padding(.vertical, DishSpace.s2)
    }

    private var header: some View {
        HStack(spacing: DishSpace.s6) {
            RowGlyph(symbol: state.symbol)
            VStack(alignment: .leading, spacing: DishSpace.s1) {
                Text(state.title).font(DishFont.mono).bold().foregroundStyle(DishTheme.onSurface)
                Text(state.kindLine).font(DishFont.caption).foregroundStyle(DishTheme.muted)
                HStack(spacing: DishSpace.s3) {
                    StatusDot(color: state.dot)
                    Text(state.line).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                }
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var actionRow: some View {
        HStack(spacing: DishSpace.s4) {
            ForEach(state.actions) { action in
                Button(action.title) { actions.perform(action.kind, state.id) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .font(DishFont.detail)
                    .disabled(!action.enabled)
            }
            Spacer()
            if let menu = state.menu {
                RowForgetMenu(state: menu, forget: forget)
            }
        }
    }

    private func pickApp(_ appId: String) {
        actions.pickApp(state.id, appId)
    }

    private func forget() {
        actions.forget(state.id)
    }

    private func cancelPairing() {
        actions.cancelPairing(state.id)
    }

    private func newCode() {
        actions.newCode(state.id)
    }
}

/// The menu behind the row, and Forget's question.
private struct RowForgetMenu: View {
    let state: MoonlightRowMenuState
    let forget: @MainActor () -> Void

    @State private var confirming = false

    var body: some View {
        Menu {
            Button(state.forget, role: .destructive, action: ask)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(DishFont.feature)
                .foregroundStyle(DishTheme.muted)
        }
        .accessibilityLabel(state.label)
        .confirmationDialog(state.confirmTitle, isPresented: $confirming, titleVisibility: .visible) {
            Button(state.forget, role: .destructive, action: forget)
            Button(state.cancel, role: .cancel) {}
        } message: {
            Text(state.confirmMessage)
        }
    }

    private func ask() {
        confirming = true
    }
}

/// The app a host's session starts, shared by every pad on the host.
struct MoonlightAppPicker: View {
    let state: AppPickerState
    let pick: @MainActor (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s1) {
            Picker(state.label, selection: Binding(get: { state.selection }, set: { pick($0) })) {
                ForEach(state.options) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.menu)
            .font(DishFont.body)
            .foregroundStyle(DishTheme.onSurface)
            if let note = state.note {
                Text(note).font(DishFont.caption).foregroundStyle(DishTheme.muted)
            }
        }
    }
}

/// The PIN the other way round from a satellite's: the dish minted it, the
/// user types it into the host's own page, and the card waits on that. It
/// goes when the host paired or refused; Cancel ends the exchange with
/// nothing written, and New code mints another.
private struct MoonlightPinCard: View {
    let state: MoonlightPinCardState
    let cancel: @MainActor () -> Void
    let newCode: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s4) {
            Text(state.title).font(DishFont.headline).foregroundStyle(DishTheme.onSurface)
            Text(state.prompt).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            HStack(spacing: DishSpace.s4) {
                ForEach(Array(state.cells.enumerated()), id: \.offset) { _, cell in
                    Text(cell)
                        .font(DishFont.largeTitle)
                        .monospacedDigit()
                        .foregroundStyle(DishTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DishSpace.s4)
                        .background(DishTheme.surfaceDim, in: RoundedRectangle(cornerRadius: DishSize.rowGlyphCorner, style: .continuous))
                }
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: DishSpace.s4) {
                ProgressView()
                Text(state.waiting).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                Spacer()
                Button(state.cancel, action: cancel)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .font(DishFont.detail)
                Button(state.newCode, action: newCode)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .font(DishFont.detail)
            }
        }
        .padding(.vertical, DishSpace.s2)
    }
}

/// FOUND ON <network>, with the spinner while the sweep looks.
struct MoonlightHostsHeader: View {
    let title: String
    let searching: String?

    var body: some View {
        HStack(spacing: DishSpace.s3) {
            SectionEyebrow(title: title, color: DishTheme.muted)
            Spacer()
            if let searching {
                ProgressView()
                Text(searching).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
    }
}
