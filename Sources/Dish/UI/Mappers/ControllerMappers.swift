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

/// BINDING › Destination: the PC the pad sends to beside its dot, or that
/// nothing is bound.
enum BindingDestinationState: Equatable {
    case bound(pcName: String, dot: Color)
    case unbound(note: String)
}

/// BINDING: where the pad sends, and, with no PC paired, the footer that
/// says where to pair one.
struct ControllerBindingState: Equatable {
    let title: String
    let destinationTitle: String
    let destination: BindingDestinationState
    let hint: String?
}

/// What the page offers besides its facts: the strip under the card, and
/// Unbind alone at the foot.
struct ControllerPageActions: Equatable {
    /// Open gamepad or the lent screens, Reconnect while the PC is lost,
    /// Bind to or Find a PC while unbound; nil with nothing to offer.
    let strip: [RowMenuEntry<ControllerAction>]?
    /// The red row at the foot; nil while nothing is bound.
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

/// The page for a pad that is attached.
struct ControllerPadState: Equatable {
    let id: String
    let status: ControllerStatusState
    let actions: ControllerPageActions
    let binding: ControllerBindingState
    /// The bind in flight or just ended for this pad; nil otherwise.
    let apply: ApplyRowState?
    /// Nil until the pad has sent a report.
    let telemetry: ControllerTelemetryState?
}

enum ControllerContent: Equatable {
    case pad(ControllerPadState)
    /// The pad left while its page was open.
    case gone(message: String)
}

/// A controller's page (C1): what the pad is and does, with Edit on the
/// toolbar for what it is set to.
struct ControllerPageState: Equatable {
    let title: String
    /// "84% battery · USB-C"; empty while the pad is away.
    let subtitle: String
    let content: ControllerContent
    /// Edit, which pushes the pad's edit page; nil while the pad is away.
    let edit: String?
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
            content: .gone(message: words.controllerGone),
            edit: nil
        )
    }
    return ControllerPageState(
        title: controllerName(controller, words: words),
        subtitle: controllerSubtitle(controller, port: port, words: words),
        content: .pad(controllerPadState(controller, paired: paired, apply: apply, pads: pads, port: port, words: words)),
        edit: words.edit
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
    ControllerPadState(
        id: controller.id,
        status: ControllerStatusState(
            symbol: controllerSymbol(controller.link),
            title: controllerName(controller, words: words),
            line: statusLine(controller, port: port, words: words),
            dot: destinationDot(controller.destination?.health)
        ),
        actions: controllerPageActions(controllerRowActions(controller, paired: paired, words: words)),
        binding: ControllerBindingState(
            title: words.binding,
            destinationTitle: words.destination,
            destination: bindingDestination(controller, words: words),
            hint: bindingHint(controller, paired: paired, words: words)
        ),
        apply: applyRowState(apply, slotId: controller.id, words: words),
        telemetry: telemetryState(controller, readings: pads, words: words)
    )
}

/// The page offers what the row's menu does: all of it but Unbind in the
/// strip under the card, and Unbind, which takes the binding away, alone
/// at the foot.
func controllerPageActions(_ actions: RowActionsState<ControllerAction>) -> ControllerPageActions {
    let strip = actions.menu.filter { !takesAway($0) }
    return ControllerPageActions(
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

/// The PC the pad sends to beside its dot, or Not bound.
private func bindingDestination(_ controller: ControllerFact, words: L10n) -> BindingDestinationState {
    guard let destination = controller.destination else { return .unbound(note: words.notBound) }
    return .bound(pcName: destination.name, dot: destinationDot(destination.health))
}

/// Unbound with nothing paired, the footer says where to pair a PC.
private func bindingHint(_ controller: ControllerFact, paired: [ConnectionFact], words: L10n) -> String? {
    guard controller.destination == nil, paired.isEmpty else { return nil }
    return words.pairAPCToBind
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
