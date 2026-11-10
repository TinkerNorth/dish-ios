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

/// A paired PC the pad can be bound to.
struct BindChoice: Equatable, Identifiable {
    let id: String
    let name: String
}

/// BINDING › Destination: the PC the pad sends to, with Unbind, or the
/// paired PCs to bind to.
enum BindingDestinationState: Equatable {
    case bound(pcName: String, dot: Color, unbind: String)
    /// `hint` says to pair a PC first while there is none to choose.
    case unbound(bindTo: String, choices: [BindChoice], hint: String?)
}

/// The apply drawn inline under Destination: where the bind stands, and
/// Try again, which binds to the same PC, once it failed.
struct ApplyRowState: Equatable {
    let text: String
    let color: Color
    let spinner: Bool
    let retry: String?
    let connectionId: String
}

/// BINDING: where the pad sends, and the pad the PC is to see.
struct ControllerBindingState: Equatable {
    let title: String
    let destinationTitle: String
    let destination: BindingDestinationState
    let emulateTitle: String
    let emulateAs: EmulatedPad
    let emulateOptions: [EmulateOption]
    /// The protocol's picker, which takes the place of Dish's four pads
    /// while the pad is bound to a Moonlight host.
    let hostEmulate: MoonlightHostEmulateState?
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

/// The page for a pad that is attached.
struct ControllerPadState: Equatable {
    let id: String
    let status: ControllerStatusState
    let binding: ControllerBindingState
    /// The bind in flight or just ended for this pad; nil otherwise.
    let apply: ApplyRowState?
    /// Nil for a pad with no switch to offer: the section is left out.
    let functions: ControllerFunctionsState?
    /// The on-screen controller's Open, which raises its gamepad; nil for a pad.
    let open: String?
    let footnote: String
}

enum ControllerContent: Equatable {
    case pad(ControllerPadState)
    /// The pad left while its page was open.
    case gone(message: String)
}

/// A controller's page (C1).
struct ControllerPageState: Equatable {
    let title: String
    /// "84% battery · USB-C"; empty while the pad is away.
    let subtitle: String
    let content: ControllerContent
}

/// `paired` are the PCs the pad can be bound to; `apply` the bind in flight
/// or just ended, drawn when it is this pad's.
func controllerPageState(
    controllers: [ControllerFact],
    paired: [ConnectionFact] = [],
    apply: ApplyFact? = nil,
    id: String,
    words: L10n = .app
) -> ControllerPageState {
    guard let controller = controllers.first(where: { $0.id == id }) else {
        return ControllerPageState(
            title: pageTitle(.controller(id: id), words: words),
            subtitle: "",
            content: .gone(message: words.controllerGone)
        )
    }
    return ControllerPageState(
        title: controllerName(controller, words: words),
        subtitle: controllerSubtitle(controller, words: words),
        content: .pad(controllerPadState(controller, paired: paired, apply: apply, words: words))
    )
}

private func controllerSubtitle(_ controller: ControllerFact, words: L10n) -> String {
    let battery = [controller.batteryPercent.map(words.batteryLevel)].compactMap(\.self)
    return (battery + [linkWord(controller.link, words: words)]).joined(separator: lineSeparator)
}

private func controllerPadState(
    _ controller: ControllerFact,
    paired: [ConnectionFact],
    apply: ApplyFact?,
    words: L10n
) -> ControllerPadState {
    let rows = controller.features.map { functionRow($0, of: controller, words: words) }
    return ControllerPadState(
        id: controller.id,
        status: ControllerStatusState(
            symbol: controllerSymbol(controller.link),
            title: controllerName(controller, words: words),
            line: statusLine(controller, words: words),
            dot: destinationDot(controller.destination?.health)
        ),
        binding: ControllerBindingState(
            title: words.binding,
            destinationTitle: words.destination,
            destination: bindingDestination(controller, paired: paired, words: words),
            emulateTitle: words.setupEmulateAs,
            emulateAs: controller.emulateAs,
            emulateOptions: EmulatedPad.allCases.map { EmulateOption(pad: $0, name: emulatedPadName($0, words: words)) },
            hostEmulate: hostEmulateState(controller, words: words)
        ),
        apply: applyRowState(apply, slotId: controller.id, words: words),
        functions: rows.isEmpty ? nil : ControllerFunctionsState(title: words.functions, rows: rows),
        open: opensPlay(controller.link) ? words.open : nil,
        footnote: words.noPadAudio
    )
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

/// The PC the pad sends to and Unbind, or Bind to with every paired PC;
/// with none paired, the hint to pair one first.
private func bindingDestination(_ controller: ControllerFact, paired: [ConnectionFact], words: L10n) -> BindingDestinationState {
    guard let destination = controller.destination else {
        let choices = paired.map { BindChoice(id: $0.id, name: connectionTitle($0)) }
        return .unbound(bindTo: words.bindTo, choices: choices, hint: choices.isEmpty ? words.pairAPCToBind : nil)
    }
    return .bound(pcName: destination.name, dot: destinationDot(destination.health), unbind: words.unbind)
}

/// The apply for this pad: its spinner while it runs, its word once it
/// ended, and Try again when it failed. Nil for another pad's, or none.
func applyRowState(_ apply: ApplyFact?, slotId: String, words: L10n = .app) -> ApplyRowState? {
    guard let apply, apply.slotId == slotId else { return nil }
    switch apply.progress {
    case .idle:
        return nil
    case .running:
        return ApplyRowState(
            text: words.applyingBinding,
            color: DishTheme.muted,
            spinner: true,
            retry: nil,
            connectionId: apply.connectionId
        )
    case .done:
        return ApplyRowState(
            text: words.bindingApplied,
            color: DishTheme.success,
            spinner: false,
            retry: nil,
            connectionId: apply.connectionId
        )
    case let .failed(failure):
        return ApplyRowState(
            text: applyFailureText(failure, words: words),
            color: DishTheme.error,
            spinner: false,
            retry: words.tryAgain,
            connectionId: apply.connectionId
        )
    }
}

/// Why a bind did not land.
func applyFailureText(_ failure: ApplyFailure, words: L10n = .app) -> String {
    switch failure {
    case .hostUnreachable: words.pcDidNotAnswer
    case .rejected: words.pcRefusedTheController
    case .padGone: words.controllerLeftBeforeApplied
    case .cancelled: words.bindingCancelled
    }
}

/// "USB-C · DualSense · 84%": the link, the family, and the level when the
/// pad reports one.
private func statusLine(_ controller: ControllerFact, words: L10n) -> String {
    let battery = [controller.batteryPercent.map(words.batteryPercent)].compactMap(\.self)
    let parts = [linkWord(controller.link, words: words), padFamilyName(controller.family, words: words)] + battery
    return parts.joined(separator: lineSeparator)
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
