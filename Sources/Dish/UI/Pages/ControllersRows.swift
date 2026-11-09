// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// One controller: its glyph, name, destination line and battery. A row
/// with a page opens it; a pad Dish cannot read has none and no chevron.
/// The on-screen controller also has Open, which raises its gamepad.
struct ControllerRow: View {
    let state: ControllerRowState
    let open: @MainActor (Page) -> Void
    let play: @MainActor () -> Void

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            if let page = state.page {
                Button {
                    open(page)
                } label: {
                    ControllerRowContent(state: state, disclosure: true)
                }
                .buttonStyle(.borderless)
            } else {
                ControllerRowContent(state: state, disclosure: false)
            }
            if let title = state.open {
                Button(title, action: play)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .font(DishFont.headline)
            }
        }
    }
}

/// The row's own layout.
private struct ControllerRowContent: View {
    let state: ControllerRowState
    let disclosure: Bool

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            RowGlyph(symbol: state.symbol)
            VStack(alignment: .leading, spacing: DishSpace.s1) {
                Text(state.name).font(DishFont.body).foregroundStyle(DishTheme.onSurface)
                HStack(spacing: DishSpace.s3) {
                    StatusDot(color: state.dot)
                    ControllerDestinationLine(line: state.destination)
                }
            }
            .lineLimit(1)
            Spacer(minLength: DishSpace.s4)
            if let battery = state.battery {
                Text(battery).font(DishFont.body).monospacedDigit().foregroundStyle(state.batteryColor)
            }
            if disclosure {
                Image(systemName: DishSymbol.disclosure).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// "Living Room PC · USB-C", the name in mono; or a note in its place.
private struct ControllerDestinationLine: View {
    let line: DestinationLine

    var body: some View {
        switch line {
        case let .bound(pcName, detail):
            HStack(spacing: 0) {
                Text(pcName).font(DishFont.monoDetail).foregroundStyle(DishTheme.onSurface)
                Text(detail).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            }
        case let .note(text):
            Text(text).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
    }
}

/// The empty state's one line above the Add button.
struct ControllersInvitation: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DishFont.body)
            .foregroundStyle(DishTheme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// Add a controller: a full-width capsule on the dim surface, the accent
/// label with a plus, and the hint under it.
struct AddControllerButton: View {
    let title: String
    let hint: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: DishSpace.s5) {
            Button(action: action) {
                Label(title, systemImage: "plus")
                    .font(DishFont.headline)
                    .foregroundStyle(DishTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DishSpace.s8)
                    .background(Capsule().fill(DishTheme.surfaceDim))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            Text(hint).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
    }
}
