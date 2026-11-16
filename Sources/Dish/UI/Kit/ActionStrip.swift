// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// A row of equal tiles under a page's card, each an action's glyph over
/// its word, as Contacts lays out message, call and mail; an entry with
/// choices opens them as a menu. Each tile calls `perform` with its action.
struct ActionStrip<Action: Hashable & Sendable>: View {
    let entries: [RowMenuEntry<Action>]
    let perform: @MainActor (Action) -> Void

    var body: some View {
        HStack(spacing: DishSpace.s4) {
            ForEach(entries) { entry in
                switch entry {
                case let .item(item):
                    Button {
                        perform(item.action)
                    } label: {
                        ActionTile(title: item.title, symbol: item.symbol)
                    }
                    .buttonStyle(.plain)
                case let .submenu(title, symbol, items):
                    Menu {
                        ForEach(items) { item in
                            Button {
                                perform(item.action)
                            } label: {
                                Label(item.title, systemImage: item.symbol)
                            }
                        }
                    } label: {
                        ActionTile(title: title, symbol: symbol)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// One tile: the glyph over the word, on the surface.
private struct ActionTile: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: DishSpace.s2) {
            Image(systemName: symbol).font(DishFont.feature).frame(height: DishSize.actionTileSymbol)
            Text(title).font(DishFont.caption).multilineTextAlignment(.center).lineLimit(2)
        }
        .foregroundStyle(DishTheme.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DishSpace.s6)
        .padding(.horizontal, DishSpace.s2)
        .background(RoundedRectangle(cornerRadius: DishSize.actionTileCorner).fill(DishTheme.surface))
        .contentShape(RoundedRectangle(cornerRadius: DishSize.actionTileCorner))
    }
}

private enum PreviewAction: Hashable {
    case touchpad
    case mouse
    case reconnect
}

#Preview("Three tiles") {
    List {
        Section {
            ActionStrip<PreviewAction>(
                entries: [
                    .item(RowActionItem(
                        action: .touchpad,
                        title: "Open touchpad",
                        symbol: "rectangle.and.hand.point.up.left",
                        destructive: false
                    )),
                    .item(RowActionItem(action: .mouse, title: "Open mouse", symbol: "cursorarrow", destructive: false)),
                    .item(RowActionItem(action: .reconnect, title: "Reconnect", symbol: RowActionSymbol.connect, destructive: false))
                ],
                perform: { _ in }
            )
        }
        .listRowBackground(EmptyView())
        .listRowInsets(EdgeInsets())
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(DishTheme.background)
}
