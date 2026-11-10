// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// One thing a row offers under a long press and, when it is a swipe, under
/// the finger: its words, its glyph, and whether it takes something away.
struct RowActionItem<Action: Hashable & Sendable>: Hashable, Identifiable {
    let action: Action
    let title: String
    let symbol: String
    let destructive: Bool

    var id: Action {
        action
    }
}

/// An entry of a row's long-press menu: an action, or a submenu of them.
enum RowMenuEntry<Action: Hashable & Sendable>: Hashable, Identifiable {
    case item(RowActionItem<Action>)
    case submenu(title: String, symbol: String, items: [RowActionItem<Action>])

    var id: Self {
        self
    }
}

/// What a row offers besides its tap: the long-press menu, and the actions a
/// swipe from either edge reveals. A row with nothing to offer has none.
struct RowActionsState<Action: Hashable & Sendable>: Hashable {
    let menu: [RowMenuEntry<Action>]
    let leading: [RowActionItem<Action>]
    let trailing: [RowActionItem<Action>]

    static var none: Self {
        RowActionsState(menu: [], leading: [], trailing: [])
    }
}

/// A row's long-press menu and its swipes, drawn from its state; each entry
/// calls `perform` with its action. A swipe never runs an action on its own
/// (no full swipe), and a destructive one wears the error colour without
/// the role, which would animate the row away before the page decides.
struct RowActions<Action: Hashable & Sendable>: ViewModifier {
    let state: RowActionsState<Action>
    let perform: @MainActor (Action) -> Void

    func body(content: Content) -> some View {
        content
            .contextMenu {
                RowMenu(entries: state.menu, perform: perform)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                ForEach(state.leading) { RowSwipe(item: $0, perform: perform) }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                ForEach(state.trailing) { RowSwipe(item: $0, perform: perform) }
            }
    }
}

/// The long-press menu: each action, and each submenu with its own.
private struct RowMenu<Action: Hashable & Sendable>: View {
    let entries: [RowMenuEntry<Action>]
    let perform: @MainActor (Action) -> Void

    var body: some View {
        ForEach(entries) { entry in
            switch entry {
            case let .item(item):
                RowMenuButton(item: item, perform: perform)
            case let .submenu(title, symbol, items):
                Menu {
                    ForEach(items) { RowMenuButton(item: $0, perform: perform) }
                } label: {
                    Label(title, systemImage: symbol)
                }
            }
        }
    }
}

/// One action of the long-press menu; a destructive one is drawn as such.
private struct RowMenuButton<Action: Hashable & Sendable>: View {
    let item: RowActionItem<Action>
    let perform: @MainActor (Action) -> Void

    var body: some View {
        Button(role: item.destructive ? .destructive : nil) {
            perform(item.action)
        } label: {
            Label(item.title, systemImage: item.symbol)
        }
    }
}

/// One action under a swipe.
private struct RowSwipe<Action: Hashable & Sendable>: View {
    let item: RowActionItem<Action>
    let perform: @MainActor (Action) -> Void

    var body: some View {
        Button {
            perform(item.action)
        } label: {
            Label(item.title, systemImage: item.symbol)
        }
        .tint(item.destructive ? DishTheme.error : DishTheme.primary)
    }
}
