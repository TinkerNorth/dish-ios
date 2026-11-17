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
    /// The pause button: Stop gamepad is the way out of play.
    case stopGamepad
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
    /// The way out of play shows even on a day another hint has shown.
    let urgent: Bool
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
            symbol: heartSymbol,
            urgent: false
        )
    case .addController:
        HintState(
            id: "dish.hint.add-a-controller",
            title: words.bringTheControllerYouOwn,
            message: addControllerHintMessage(port, words: words),
            symbol: "gamecontroller",
            urgent: false
        )
    case .stopGamepad:
        HintState(
            id: "dish.hint.stop-gamepad",
            title: words.leaveThroughThePauseMenu,
            message: words.stopGamepadTakesYouBack,
            symbol: PlaySymbol.stop,
            urgent: true
        )
    case .dim:
        HintState(
            id: "dish.hint.dim",
            title: words.dimTheScreenWhileYouPlay,
            message: words.dimHintMessage,
            symbol: "moon.fill",
            urgent: false
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
/// or bound one in setup, stopped the gamepad, or dimmed the screen. An
/// event the machine refused, or a cover the system lowered, teaches nothing.
func learnedHint(_ event: NavigationEvent, from before: NavigationState, to after: NavigationState) -> Hint? {
    let coverMoved = before.cover != after.cover
    switch event {
    case .push(.support), .show(.support, _): return .supportDish
    case .openSetup(.addController): return .addController
    case .setupEnded(.bound): return coverMoved ? .addController : nil
    case .closePlay: return coverMoved ? .stopGamepad : nil
    case .dim: return coverMoved ? .dim : nil
    case .select, .push, .show, .pop, .pathChanged, .openSetup, .setupEnded, .openPlay, .wake, .coverDismissed, .openSheet,
         .closeSheet, .pairingChanged, .connectTo:
        return nil
    }
}
