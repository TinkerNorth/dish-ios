// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import Observation

/// Owns one piece of state and exposes it read-only. The owner mutates it
/// through `setState`, which is distinct-until-changed: an equal value is
/// not published, so an observer never re-renders for a write that changed
/// nothing and cannot loop through its own write. A store wraps a setting,
/// a socket or a cache and holds one of these; the hot path never routes
/// through it.
@MainActor
@Observable
package final class StateSource<State: Equatable> {
    package private(set) var state: State

    package init(initial: State) {
        state = initial
    }

    /// Replace the state. Equal values are dropped before publishing.
    package func setState(_ next: State) {
        guard next != state else { return }
        state = next
    }

    /// Replace the state with the result of `reducer` applied to the
    /// current one, under the same distinct-until-changed rule.
    package func updateState(_ reducer: (State) -> State) {
        setState(reducer(state))
    }
}
