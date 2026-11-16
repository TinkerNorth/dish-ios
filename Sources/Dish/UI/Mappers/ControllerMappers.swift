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
    let mark: StatusMark
}

/// BINDING › Destination: the PC the pad sends to beside its mark, or that
/// nothing is bound.
enum BindingDestinationState: Equatable {
    case bound(pcName: String, mark: StatusMark)
    case unbound(note: String)
}

/// A PC the pad can be bound to, and whether it is the one it sends to.
struct BindChoice: Equatable, Identifiable {
    let id: String
    let name: String
    let current: Bool
}

/// How the destination is changed: a menu of the active PCs, or Find a PC
/// when none is up.
enum BindingPickerState: Equatable {
    case choices([BindChoice])
    case findPC(String)
}

/// BINDING: where the pad sends, the picker that changes it, and the footer
/// that says what to do on the Connections tab when nothing can be picked.
struct ControllerBindingState: Equatable {
    let title: String
    let destinationTitle: String
    let destination: BindingDestinationState
    let picker: BindingPickerState
    let hint: String?
}

/// What a controller offers besides its facts: the strip under its row, and
/// Unbind alone at the foot of its page.
struct ControllerOffers: Equatable {
    /// Open gamepad or the lent screens, Reconnect while the PC is lost,
    /// Bind to or Find a PC while unbound; nil with nothing to offer.
    let strip: [RowMenuEntry<ControllerAction>]?
    /// The red row at the foot of the page; nil while nothing is bound.
    let unbind: RowActionItem<ControllerAction>?
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

/// One rate of TELEMETRY: the stream and its rate.
struct TelemetryRowState: Equatable, Identifiable {
    let id: String
    let label: String
    let value: String
}

/// TELEMETRY: the rates of the streams the pad has, read off the same
/// trackers Diagnostics shows.
struct ControllerTelemetryState: Equatable {
    let title: String
    let rows: [TelemetryRowState]
}

/// The page for a pad that is attached: what it is set to, over where it
/// sends; its actions are its row's.
struct ControllerPadState: Equatable {
    let id: String
    let status: ControllerStatusState
    let binding: ControllerBindingState
    /// The bind in flight or just ended for this pad; nil otherwise.
    let apply: ApplyRowState?
    /// "Updating…" while the PC applies the pad's settings; nil otherwise.
    let updating: String?
    let emulate: ControllerEmulateState
    /// Nil for a pad with no switch to offer: the section is left out.
    let functions: ControllerFunctionsState?
    let footnote: String
    /// The row that pushes the Dead zones page; nil for the on-screen gamepad.
    let deadZones: String?
    /// Nil until the pad has sent a report.
    let telemetry: ControllerTelemetryState?
    /// Unbind, the red row at the foot; nil while nothing is bound.
    let unbind: RowActionItem<ControllerAction>?
}

enum ControllerContent: Equatable {
    case pad(ControllerPadState)
    /// The pad left while its page was open.
    case gone(message: String)
}

/// A controller's page (C1): what the pad is set to, over where it sends.
struct ControllerPageState: Equatable {
    let title: String
    /// "84% battery · USB-C"; empty while the pad is away.
    let subtitle: String
    let content: ControllerContent
}

/// `paired` are the PCs the pad can be bound to; `apply` the bind in flight
/// or just ended, drawn when it is this pad's; `port` the one an attached
/// pad is attached to.
func controllerPageState(
    controllers: [ControllerFact],
    paired: [ConnectionFact] = [],
    apply: ApplyFact? = nil,
    pads: [PadDiagnostics] = [],
    port: DevicePort = .usbC,
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
        subtitle: controllerSubtitle(controller, port: port, words: words),
        content: .pad(controllerPadState(controller, paired: paired, apply: apply, pads: pads, port: port, words: words))
    )
}

private func controllerSubtitle(_ controller: ControllerFact, port: DevicePort, words: L10n) -> String {
    let battery = [controller.batteryPercent.map(words.batteryLevel)].compactMap(\.self)
    return (battery + [linkWord(controller.link, port: port, words: words)]).joined(separator: lineSeparator)
}

private func controllerPadState(
    _ controller: ControllerFact,
    paired: [ConnectionFact],
    apply: ApplyFact?,
    pads: [PadDiagnostics],
    port: DevicePort,
    words: L10n
) -> ControllerPadState {
    let rows = controller.features.map { functionRow($0, of: controller, words: words) }
    let offers = controllerOffers(controllerRowActions(controller, paired: paired, words: words))
    return ControllerPadState(
        id: controller.id,
        status: ControllerStatusState(
            symbol: controllerSymbol(controller.link),
            title: controllerName(controller, words: words),
            line: statusLine(controller, port: port, words: words),
            mark: destinationMark(controller.destination?.health)
        ),
        binding: ControllerBindingState(
            title: words.binding,
            destinationTitle: words.destination,
            destination: bindingDestination(controller, words: words),
            picker: bindingPicker(controller, paired: paired, words: words),
            hint: bindingHint(controller, paired: paired, words: words)
        ),
        apply: applyRowState(apply, slotId: controller.id, words: words),
        updating: updatingLine(controller, words: words),
        emulate: ControllerEmulateState(
            title: words.setupEmulateAs,
            emulateAs: controller.emulateAs,
            options: EmulatedPad.allCases.map { EmulateOption(pad: $0, name: emulatedPadName($0, words: words)) },
            host: hostEmulateState(controller, words: words)
        ),
        functions: rows.isEmpty ? nil : ControllerFunctionsState(title: words.functions, rows: rows),
        footnote: words.noPadAudio,
        deadZones: hasDeadZones(controller.link) ? words.deadZones : nil,
        telemetry: telemetryState(controller, readings: pads, words: words),
        unbind: offers.unbind
    )
}

/// The row's strip offers what its menu does, all but Unbind, which takes
/// the binding away and stands alone at the foot of the page.
func controllerOffers(_ actions: RowActionsState<ControllerAction>) -> ControllerOffers {
    let strip = actions.menu.filter { !takesAway($0) }
    return ControllerOffers(
        strip: strip.isEmpty ? nil : strip,
        unbind: actions.menu.compactMap(menuItem).first(where: \.destructive)
    )
}

private func takesAway(_ entry: RowMenuEntry<ControllerAction>) -> Bool {
    switch entry {
    case let .item(item): item.destructive
    case .submenu: false
    }
}

private func menuItem(_ entry: RowMenuEntry<ControllerAction>) -> RowActionItem<ControllerAction>? {
    switch entry {
    case let .item(item): item
    case .submenu: nil
    }
}

/// The PC the pad sends to beside its mark, or Not bound.
private func bindingDestination(_ controller: ControllerFact, words: L10n) -> BindingDestinationState {
    guard let destination = controller.destination else { return .unbound(note: words.notBound) }
    return .bound(pcName: destination.name, mark: destinationMark(destination.health))
}

/// The active PCs, the one the pad sends to marked; with none up, Find a PC.
private func bindingPicker(_ controller: ControllerFact, paired: [ConnectionFact], words: L10n) -> BindingPickerState {
    let choices = bindableConnections(paired).map { pc in
        BindChoice(id: pc.id, name: connectionTitle(pc), current: pc.id == controller.destination?.id)
    }
    return choices.isEmpty ? .findPC(words.findAPC) : .choices(choices)
}

/// Unbound with nothing to pick, the footer says what to do on the
/// Connections tab: pair a PC when none is, connect one when none is up.
private func bindingHint(_ controller: ControllerFact, paired: [ConnectionFact], words: L10n) -> String? {
    guard controller.destination == nil, bindableConnections(paired).isEmpty else { return nil }
    return paired.isEmpty ? words.pairAPCToBind : words.connectAPCToBind
}

/// "Updating…" while the PC the pad is bound to applies its settings.
func updatingLine(_ controller: ControllerFact, words: L10n = .app) -> String? {
    guard controller.destination?.updating == true else { return nil }
    return words.updating
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

/// The Gamepad rate, and the motion and touch rates when the pad has the
/// hardware for them.
private func telemetryState(_ controller: ControllerFact, readings: [PadDiagnostics], words: L10n) -> ControllerTelemetryState? {
    guard let reading = readings.first(where: { $0.controller.id == controller.id }), reading.reports > 0 else { return nil }
    let has = Set(controller.features.map(\.feature))
    let gamepad = TelemetryRowState(id: "gamepad", label: words.gamepad, value: words.hertz(reading.rates.reportHz))
    let motion = TelemetryRowState(id: "motion", label: words.setupMotion, value: words.hertz(reading.rates.motionHz))
    let touch = TelemetryRowState(id: "touch", label: words.touch, value: words.hertz(reading.rates.touchHz))
    let rows = [gamepad] + (has.contains(.motion) ? [motion] : []) + (has.contains(.touchpad) ? [touch] : [])
    return ControllerTelemetryState(title: words.telemetry, rows: rows)
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
private func statusLine(_ controller: ControllerFact, port: DevicePort, words: L10n) -> String {
    let battery = [controller.batteryPercent.map(words.batteryPercent)].compactMap(\.self)
    let parts = [linkWord(controller.link, port: port, words: words), padFamilyName(controller.family, words: words)] + battery
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
