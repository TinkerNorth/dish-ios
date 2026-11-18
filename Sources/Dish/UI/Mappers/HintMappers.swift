// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// A hint TipKit shows beside a control until the person does what it
/// points at, or closes it.
enum Hint: CaseIterable {
    /// The heart on the Controllers toolbar: Support Dish.
    case supportDish
    /// Add a controller: pads pair in Settings, not in Dish.
    case addController
    /// The session accessory's Dim.
    case dim
}

/// A hint as TipKit draws it: the name TipKit keeps it under, its words and
/// its glyph.
struct HintState: Equatable {
    let id: String
    let title: String
    let message: String
    let symbol: String
}

/// `port` words Add a controller's: a Lightning iPhone's wired road runs
/// through the adapter.
func hintState(_ hint: Hint, port: DevicePort = .usbC, words: L10n = .app) -> HintState {
    switch hint {
    case .supportDish:
        HintState(
            id: "dish.hint.support-dish",
            title: words.supportDish,
            message: words.supportDishHintMessage,
            symbol: heartSymbol
        )
    case .addController:
        HintState(
            id: "dish.hint.add-a-controller",
            title: words.bringTheControllerYouOwn,
            message: addControllerHintMessage(port, words: words),
            symbol: "gamecontroller"
        )
    case .dim:
        HintState(
            id: "dish.hint.dim",
            title: words.dimTheScreenWhileYouPlay,
            message: words.dimHintMessage,
            symbol: "moon.fill"
        )
    }
}

/// Pads pair in Settings; on a Lightning iPhone the wired road runs through
/// the adapter, and the hint says so.
private func addControllerHintMessage(_ port: DevicePort, words: L10n) -> String {
    switch port {
    case .usbC: words.pairYourPadHintMessage
    case .lightning: words.pairYourPadThroughTheAdapterHintMessage
    }
}

/// The hint the person no longer needs once `event` moved the navigation
/// from `before` to `after`: they opened Support Dish, added a controller
/// or bound one in setup, or dimmed the screen. An event the machine
/// refused, or a cover the system lowered, teaches nothing.
func learnedHint(_ event: NavigationEvent, from before: NavigationState, to after: NavigationState) -> Hint? {
    let coverMoved = before.cover != after.cover
    switch event {
    case .push(.support), .show(.support, _): return .supportDish
    case .openSetup(.addController): return .addController
    case .setupEnded(.bound): return coverMoved ? .addController : nil
    case .dim: return coverMoved ? .dim : nil
    case .select, .push, .show, .pop, .pathChanged, .openSetup, .setupEnded, .openPlay, .closePlay, .wake, .coverDismissed,
         .openSheet, .closeSheet, .pairingChanged, .connectTo:
        return nil
    }
}
