// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The card at the head of the page: the pad, its link, family and battery.
struct ControllerStatusState: Equatable {
    let symbol: String
    let title: String
    let line: String
    let dot: Color
}

/// BINDING: where the pad sends, which the network wave fills, and the pad
/// the PC is to see.
struct ControllerBindingState: Equatable {
    let title: String
    let destinationTitle: String
    let destination: String
    /// The row opens the PC picker once there is one to open.
    let destinationEnabled: Bool
    let emulateTitle: String
    let emulateAs: EmulatedPad
    let emulateOptions: [EmulateOption]
}

/// One switch of FUNCTIONS.
struct ControllerFunctionRowState: Equatable, Identifiable {
    let feature: SlotSwitch
    let symbol: String
    let title: String
    let isOn: Bool

    var id: SlotSwitch {
        feature
    }
}

/// FUNCTIONS: the switches the pad has the hardware for.
struct ControllerFunctionsState: Equatable {
    let title: String
    let rows: [ControllerFunctionRowState]
}

/// The page for a pad that is attached.
struct ControllerPadState: Equatable {
    let id: String
    let status: ControllerStatusState
    let binding: ControllerBindingState
    /// Nil for a pad with no switch to offer: the section is left out.
    let functions: ControllerFunctionsState?
    let footnote: String
}

enum ControllerContent: Equatable {
    case pad(ControllerPadState)
    /// The pad left while its page was open.
    case gone(message: String)
}

/// A controller's page (C1) without its PC half.
struct ControllerPageState: Equatable {
    let title: String
    /// "84% battery · USB-C"; empty while the pad is away.
    let subtitle: String
    let content: ControllerContent
}

func controllerPageState(controllers: [ControllerFact], id: String, words: L10n = .app) -> ControllerPageState {
    guard let controller = controllers.first(where: { $0.id == id }) else {
        return ControllerPageState(
            title: pageTitle(.controller(id: id), words: words),
            subtitle: "",
            content: .gone(message: words.controllerGone)
        )
    }
    return ControllerPageState(
        title: controller.name,
        subtitle: controllerSubtitle(controller, words: words),
        content: .pad(controllerPadState(controller, words: words))
    )
}

private func controllerSubtitle(_ controller: ControllerFact, words: L10n) -> String {
    let battery = [controller.batteryPercent.map(words.batteryLevel)].compactMap(\.self)
    return (battery + [linkWord(controller.link, words: words)]).joined(separator: lineSeparator)
}

private func controllerPadState(_ controller: ControllerFact, words: L10n) -> ControllerPadState {
    let rows = controller.features.map { functionRow($0, words: words) }
    return ControllerPadState(
        id: controller.id,
        status: ControllerStatusState(
            symbol: controllerSymbol(controller.link),
            title: controller.name,
            line: statusLine(controller, words: words),
            dot: destinationDot(controller.destination?.health)
        ),
        binding: ControllerBindingState(
            title: words.binding,
            destinationTitle: words.destination,
            destination: words.notBound,
            destinationEnabled: false,
            emulateTitle: words.setupEmulateAs,
            emulateAs: controller.emulateAs,
            emulateOptions: EmulatedPad.allCases.map { EmulateOption(pad: $0, name: emulatedPadName($0, words: words)) }
        ),
        functions: rows.isEmpty ? nil : ControllerFunctionsState(title: words.functions, rows: rows),
        footnote: words.noPadAudio
    )
}

/// "USB-C · DualSense · 84%": the link, the family, and the level when the
/// pad reports one.
private func statusLine(_ controller: ControllerFact, words: L10n) -> String {
    let battery = [controller.batteryPercent.map(words.batteryPercent)].compactMap(\.self)
    let parts = [linkWord(controller.link, words: words), padFamilyName(controller.family, words: words)] + battery
    return parts.joined(separator: lineSeparator)
}

private func functionRow(_ fact: ControllerFeatureFact, words: L10n) -> ControllerFunctionRowState {
    ControllerFunctionRowState(
        feature: fact.feature,
        symbol: functionSymbol(fact.feature),
        title: functionTitle(fact.feature, words: words),
        isOn: fact.enabled
    )
}

func functionTitle(_ feature: SlotSwitch, words: L10n = .app) -> String {
    switch feature {
    case .motion: words.setupMotion
    case .rumble: words.carriesRumble
    case .triggerEffects: words.adaptiveTriggers
    case .lightbar: words.lightBar
    case .playerLeds: words.playerLeds
    case .touchpad: words.carriesTouchpad
    }
}

func functionSymbol(_ feature: SlotSwitch) -> String {
    switch feature {
    case .motion: "gyroscope"
    case .rumble: "iphone.radiowaves.left.and.right"
    case .triggerEffects: "l2.button.roundedtop.horizontal"
    case .lightbar: "lightbulb"
    case .playerLeds: "person.crop.circle"
    case .touchpad: "hand.point.up.left"
    }
}

/// The word for the pad's family; a family the catalog has no pad for is a
/// plain controller.
func padFamilyName(_ family: PadFamily, words: L10n = .app) -> String {
    switch family {
    case .dualSense: words.dualSense
    case .dualShock4: words.dualShock4
    case .xbox: words.xboxWireless
    case .nintendo: words.nintendo
    case .other: words.controller
    }
}
