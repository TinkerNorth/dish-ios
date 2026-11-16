// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine

/// What a controller's actions do, wherever they are offered: its row on
/// the Controllers tab and its page share this one dispatch, each action an
/// intent on the model or an event to the store.
struct ControllerActionRouter {
    let model: AppModel
    let navigation: NavigationStore

    @MainActor func perform(_ action: ControllerAction) {
        switch action {
        case .openGamepad: navigation.send(.openPlay(.gamepad))
        case let .openSurface(slotId, screen): openSurface(slotId, screen)
        case let .bind(slotId, connectionId): model.bind(slotId: slotId, to: connectionId)
        case let .unbind(slotId): model.unbind(slotId: slotId)
        case let .reconnect(connectionId): model.connect(connectionId)
        case .findPC: navigation.send(.select(.connections))
        }
    }

    /// The phone is aimed at the pad, then its screen opens over the pad's slot.
    @MainActor private func openSurface(_ slotId: String, _ screen: PlayScreen) {
        model.aimPlay(at: slotId)
        navigation.send(.openPlay(screen))
    }
}
