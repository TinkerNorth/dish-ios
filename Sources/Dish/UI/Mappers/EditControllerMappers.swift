// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// Emulate as: Dish's four pads, or the protocol's four while the pad is
/// bound to a Moonlight host.
struct ControllerEmulateState: Equatable {
    let title: String
    let emulateAs: EmulatedPad
    let options: [EmulateOption]
    /// The protocol's picker, which takes the place of Dish's four pads
    /// while the pad is bound to a Moonlight host.
    let host: MoonlightHostEmulateState?
}

/// Emulate as for a pad on a Moonlight host: Auto and the protocol's three
/// types, the one picked (nil for Auto) and the line under the picker.
struct MoonlightHostEmulateState: Equatable {
    let options: [MoonlightEmulateOption]
    let selection: Int?
    let detail: String
}

/// The line under the Motion row: why motion does or does not reach the PC.
struct MotionRowStatus: Equatable {
    let text: String
    let warns: Bool

    var color: Color {
        warns ? DishTheme.warning : DishTheme.muted
    }
}

/// The gyro chip's state worded for the row; only the two states the
/// satellite is to blame for warn, the rest read as the row's ordinary on
/// and off.
func motionRowStatus(_ state: MotionIndicatorState, words: L10n = .app) -> MotionRowStatus {
    switch state {
    case .unavailable: MotionRowStatus(text: words.motionNoGyroscope, warns: false)
    case .userDisabled: MotionRowStatus(text: words.motionTurnedOff, warns: false)
    case .notForwarded: MotionRowStatus(text: words.motionNotSent, warns: false)
    case .noHostSink: MotionRowStatus(text: words.motionHostCannotReceive, warns: true)
    case .backendBroken: MotionRowStatus(text: words.motionServerCannotDeliver, warns: true)
    case .forwarding: MotionRowStatus(text: words.motionStreaming, warns: false)
    }
}

/// The pad, the switch, the binding and the satellite's word, most blocking
/// first; a satellite that has not answered yet reads as fine.
func motionIndicator(_ controller: ControllerFact, switchOn: Bool) -> MotionIndicatorState {
    motionIndicatorFor(MotionIndicatorInputs(
        hasGyro: true,
        userEnabled: switchOn,
        carriesOnConnection: controller.motion.carries,
        hostHasSinkForType: controller.motion.status?.sinkSupportedForType ?? true,
        backendOk: controller.motion.status?.backendOk ?? true
    ))
}

/// One switch of FUNCTIONS.
struct ControllerFunctionRowState: Equatable, Identifiable {
    let feature: SlotSwitch
    let symbol: String
    let title: String
    let isOn: Bool
    let status: MotionRowStatus?

    var id: SlotSwitch {
        feature
    }
}

/// FUNCTIONS: the switches the pad has the hardware for.
struct ControllerFunctionsState: Equatable {
    let title: String
    let rows: [ControllerFunctionRowState]
}

/// The edit page for a pad that is attached.
struct EditControllerPadState: Equatable {
    let id: String
    let emulate: ControllerEmulateState
    /// Nil for a pad with no switch to offer: the section is left out.
    let functions: ControllerFunctionsState?
    let footnote: String
    /// The row that pushes the Dead zones page; nil for the on-screen gamepad.
    let deadZones: String?
}

enum EditControllerContent: Equatable {
    case pad(EditControllerPadState)
    /// The pad left while its page was open.
    case gone(message: String)
}

/// Edit controller: what the pad is set to, pushed from its page's Edit.
struct EditControllerPageState: Equatable {
    let title: String
    /// The pad's name; empty while the pad is away.
    let subtitle: String
    let content: EditControllerContent
}

func editControllerPageState(controllers: [ControllerFact], id: String, words: L10n = .app) -> EditControllerPageState {
    let title = pageTitle(.editController(id: id), words: words)
    guard let controller = controllers.first(where: { $0.id == id }) else {
        return EditControllerPageState(title: title, subtitle: "", content: .gone(message: words.controllerGone))
    }
    return EditControllerPageState(
        title: title,
        subtitle: controllerName(controller, words: words),
        content: .pad(editControllerPadState(controller, words: words))
    )
}

private func editControllerPadState(_ controller: ControllerFact, words: L10n) -> EditControllerPadState {
    let rows = controller.features.map { functionRow($0, of: controller, words: words) }
    return EditControllerPadState(
        id: controller.id,
        emulate: ControllerEmulateState(
            title: words.setupEmulateAs,
            emulateAs: controller.emulateAs,
            options: EmulatedPad.allCases.map { EmulateOption(pad: $0, name: emulatedPadName($0, words: words)) },
            host: hostEmulateState(controller, words: words)
        ),
        functions: rows.isEmpty ? nil : ControllerFunctionsState(title: words.functions, rows: rows),
        footnote: words.noPadAudio,
        deadZones: hasDeadZones(controller.link) ? words.deadZones : nil
    )
}

/// The on-screen gamepad has no stick drift to tune out.
private func hasDeadZones(_ link: ControllerLink) -> Bool {
    switch link {
    case .usbC, .bluetooth: true
    case .onScreen: false
    }
}

/// The protocol's picker for a pad bound to a Moonlight host; nil for any
/// other pad, which keeps Dish's four.
private func hostEmulateState(_ controller: ControllerFact, words: L10n) -> MoonlightHostEmulateState? {
    guard let emulation = controller.hostEmulation, let host = controller.destination?.name else { return nil }
    let hasMotion = controller.features.contains { $0.feature == .motion }
    return MoonlightHostEmulateState(
        options: moonlightEmulateOptions(words: words),
        selection: moonlightEmulateSelection(emulation),
        detail: moonlightEmulateDetail(emulation, hasMotion: hasMotion, host: host, words: words)
    )
}

private func functionRow(_ fact: ControllerFeatureFact, of controller: ControllerFact, words: L10n) -> ControllerFunctionRowState {
    ControllerFunctionRowState(
        feature: fact.feature,
        symbol: functionSymbol(fact.feature),
        title: functionTitle(fact.feature, words: words),
        isOn: fact.enabled,
        status: motionStatus(fact, of: controller, words: words)
    )
}

/// Only the Motion row has a line under it.
private func motionStatus(_ fact: ControllerFeatureFact, of controller: ControllerFact, words: L10n) -> MotionRowStatus? {
    switch fact.feature {
    case .motion: motionRowStatus(motionIndicator(controller, switchOn: fact.enabled), words: words)
    case .rumble, .triggerEffects, .lightbar, .playerLeds, .touchpad: nil
    }
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
