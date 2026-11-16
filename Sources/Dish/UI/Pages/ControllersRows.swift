// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// One controller: its glyph, name, destination line and battery, and under
/// them the strip of what it offers, as Android's card carries its buttons.
/// A row with a page opens the controller's settings, pushed with a chevron
/// from a stack, selected beside a split's list; a pad Dish cannot read has
/// none. A long press and a swipe offer the same actions.
struct ControllerRow: View {
    let state: ControllerRowState
    var layout = TabLayout.stack
    let open: @MainActor (Page) -> Void
    let act: @MainActor (ControllerAction) -> Void

    var body: some View {
        switch rowOpening(state.page, layout: layout) {
        case let .push(page):
            VStack(alignment: .leading, spacing: DishSpace.s4) {
                Button {
                    open(page)
                } label: {
                    ControllerRowContent(state: state, disclosure: true)
                }
                .buttonStyle(.borderless)
                strip
            }
            .modifier(rowActions)
        case let .select(page):
            VStack(alignment: .leading, spacing: DishSpace.s4) {
                ControllerRowContent(state: state, disclosure: false)
                strip
            }
            .modifier(rowActions)
            .tag(page)
        case .inert:
            ControllerRowContent(state: state, disclosure: false)
                .modifier(rowActions)
        }
    }

    /// What the controller offers, as tiles on the row's dim surface.
    @ViewBuilder private var strip: some View {
        if let strip = state.strip {
            ActionStrip(entries: strip, fill: DishTheme.surfaceDim, perform: act)
        }
    }

    private var rowActions: RowActions<ControllerAction> {
        RowActions(state: state.actions, perform: act)
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
                    StatusMarkView(mark: state.mark)
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

/// Add a controller: a full-width capsule on the dim surface, the accent
/// label with a plus, the hint under it, and TipKit's hint beside it.
struct AddControllerButton: View {
    let title: String
    let hint: String
    let tipKitHint: HintState
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
            .hint(tipKitHint)
            Text(hint).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
    }
}
