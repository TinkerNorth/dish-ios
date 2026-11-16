// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// The second line of a controller row.
enum DestinationLine: Equatable {
    /// The PC's name in mono, then `detail` ("· USB-C") in plain text.
    case bound(pcName: String, detail: String)
    /// A line with no PC to name: "Connection lost", "Not bound".
    case note(String)
}

/// What a controller offers: its row's long-press menu and swipes, and its
/// page's strip under the card and Unbind at the foot.
enum ControllerAction: Hashable {
    /// The on-screen controller's gamepad.
    case openGamepad
    /// The touchpad or the mouse screen the phone lends the pad, over its slot.
    case openSurface(slotId: String, screen: PlayScreen)
    case bind(slotId: String, connectionId: String)
    case unbind(slotId: String)
    /// Reach for the PC the pad is bound to, which was lost.
    case reconnect(connectionId: String)
    /// Nothing paired to bind to: the Connections tab.
    case findPC
}

/// One controller row (A2).
struct ControllerRowState: Equatable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let destination: DestinationLine
    let mark: StatusMark
    /// Nil when the controller reports no level.
    let battery: String?
    let batteryColor: Color
    /// The controller's page; nil for a pad Dish cannot read, which has
    /// nothing to set.
    let page: Page?
    /// The strip under the row: what the controller offers, as Android's
    /// card carries its buttons; nil with nothing to offer.
    let strip: [RowMenuEntry<ControllerAction>]?
    /// The long-press menu and the swipes, which offer the same.
    let actions: RowActionsState<ControllerAction>
}

/// A toolbar button that pushes a page: its accessibility title and glyph.
struct ToolbarLinkState: Equatable {
    let title: String
    let symbol: String
    let page: Page
}

/// The hints TipKit points at on the Controllers tab.
struct ControllersHints: Equatable {
    /// The heart's; nil while no controller is listed, so it waits until
    /// Dish is set up.
    let support: HintState?
    /// Add a controller's.
    let add: HintState
}

/// The Controllers tab.
struct ControllersPageState: Equatable {
    let title: String
    /// The pads iOS sees, then the on-screen controller, which is always listed.
    let rows: [ControllerRowState]
    let addTitle: String
    let addHint: String
    /// The heart on the toolbar: Support Dish.
    let support: ToolbarLinkState
    let hints: ControllersHints
    /// The Lightning note while no pad is listed; nil otherwise.
    let adapter: AdapterNoteState?
}

/// The level at and below which a battery reads in the error colour.
private let lowBatteryPercent = 15

/// `apply` is the bind in flight or just ended, which speaks on its pad's
/// row in place of the destination; `paired` are the PCs a row's Bind to
/// offers; `port` is the one this device hosts a wired pad through.
func controllersPageState(
    controllers: [ControllerFact],
    apply: ApplyFact? = nil,
    paired: [ConnectionFact] = [],
    port: DevicePort = .usbC,
    words: L10n = .app
) -> ControllersPageState {
    let padListed = controllers.contains { $0.link != .onScreen }
    return ControllersPageState(
        title: words.controllers,
        rows: controllers.map { controllerRow($0, apply: apply, paired: paired, port: port, words: words) },
        addTitle: words.addAController,
        addHint: words.addAControllerHint,
        support: ToolbarLinkState(title: words.supportDish, symbol: heartSymbol, page: .support),
        hints: controllersHints(padListed: padListed, port: port, words: words),
        adapter: padListed ? nil : adapterNote(port: port, words: words)
    )
}

/// The heart's hint waits until a pad is listed.
private func controllersHints(padListed: Bool, port: DevicePort, words: L10n) -> ControllersHints {
    ControllersHints(
        support: padListed ? hintState(.supportDish, words: words) : nil,
        add: hintState(.addController, port: port, words: words)
    )
}

func controllerRow(
    _ controller: ControllerFact,
    apply: ApplyFact? = nil,
    paired: [ConnectionFact] = [],
    port: DevicePort = .usbC,
    words: L10n = .app
) -> ControllerRowState {
    let line = rowLine(controller, apply: apply, port: port, words: words)
    let actions = controllerRowActions(controller, paired: paired, words: words)
    return ControllerRowState(
        id: controller.id,
        symbol: controllerSymbol(controller.link),
        name: controllerName(controller, words: words),
        destination: line.destination,
        mark: line.mark,
        battery: controller.batteryPercent.map(words.batteryPercent),
        batteryColor: batteryColor(controller.batteryPercent),
        page: controller.supported ? .controller(id: controller.id) : nil,
        strip: controllerOffers(actions).strip,
        actions: actions
    )
}

/// The row's menu and swipes, which the page's strip and foot are drawn
/// from too: Open gamepad and the lent screens, Reconnect and Unbind for a
/// bound controller, Bind to or Find a PC for an unbound one.
func controllerRowActions(
    _ controller: ControllerFact,
    paired: [ConnectionFact],
    words: L10n = .app
) -> RowActionsState<ControllerAction> {
    guard controller.supported else { return .none }
    let open = opensGamepad(controller) ? [openItem(words: words)] : []
    let screens = controller.surfaces.map { surfaceItem(controller.id, $0, words: words) }
    switch controller.destination {
    case let .some(destination):
        let lost = destination.health == .lost ? destination.id : nil
        return boundActions(controller.id, open: open, screens: screens, lost: lost, words: words)
    case nil:
        return unboundActions(controller.id, open: open, paired: paired, words: words)
    }
}

private func openItem(words: L10n) -> RowActionItem<ControllerAction> {
    RowActionItem(action: .openGamepad, title: words.openGamepad, symbol: RowActionSymbol.open, destructive: false)
}

private func surfaceItem(_ slotId: String, _ screen: PlayScreen, words: L10n) -> RowActionItem<ControllerAction> {
    RowActionItem(
        action: .openSurface(slotId: slotId, screen: screen),
        title: openSurfaceTitle(screen, words: words),
        symbol: playScreenSymbol(screen),
        destructive: false
    )
}

/// "Open gamepad", "Open touchpad", "Open mouse".
func openSurfaceTitle(_ screen: PlayScreen, words: L10n = .app) -> String {
    switch screen {
    case .gamepad: words.openGamepad
    case .touchpad: words.openTouchpad
    case .mouse: words.openMouse
    }
}

private func boundActions(
    _ slotId: String,
    open: [RowActionItem<ControllerAction>],
    screens: [RowActionItem<ControllerAction>],
    lost connectionId: String?,
    words: L10n
) -> RowActionsState<ControllerAction> {
    let unbind = RowActionItem(
        action: ControllerAction.unbind(slotId: slotId),
        title: words.unbind,
        symbol: RowActionSymbol.unbind,
        destructive: true
    )
    let reconnect = connectionId.map { id in
        [RowActionItem(
            action: ControllerAction.reconnect(connectionId: id),
            title: words.reconnect,
            symbol: RowActionSymbol.connect,
            destructive: false
        )]
    } ?? []
    return RowActionsState(
        menu: (open + screens + reconnect + [unbind]).map(RowMenuEntry.item),
        leading: open,
        trailing: reconnect + [unbind]
    )
}

/// Bind to is a submenu of the active PCs; with none to bind to, Find a PC.
private func unboundActions(
    _ slotId: String,
    open: [RowActionItem<ControllerAction>],
    paired: [ConnectionFact],
    words: L10n
) -> RowActionsState<ControllerAction> {
    let active = bindableConnections(paired)
    guard !active.isEmpty else {
        let find = RowActionItem(action: ControllerAction.findPC, title: words.findAPC, symbol: RowActionSymbol.pair, destructive: false)
        return RowActionsState(menu: (open + [find]).map(RowMenuEntry.item), leading: open, trailing: [find])
    }
    let choices = active.map { pc in
        RowActionItem(
            action: ControllerAction.bind(slotId: slotId, connectionId: pc.id),
            title: connectionTitle(pc),
            symbol: connectionSymbol(pc.kind),
            destructive: false
        )
    }
    let bindTo = [RowMenuEntry.submenu(title: words.bindTo, symbol: RowActionSymbol.bind, items: choices)]
    return RowActionsState(menu: open.map(RowMenuEntry.item) + bindTo, leading: open, trailing: [])
}

/// The PCs a controller can be bound to right now: the ones whose link is
/// up, as Android offers them; a resting PC is reached for from its own row
/// first.
func bindableConnections(_ paired: [ConnectionFact]) -> [ConnectionFact] {
    paired.filter { isBindable($0.state) }
}

func isBindable(_ state: ConnectionState) -> Bool {
    switch state {
    case .online, .unsteady: true
    case .connecting, .offline, .needsPairing: false
    }
}

/// A row's second line and its mark.
private struct RowLine {
    let destination: DestinationLine
    let mark: StatusMark
}

/// A bind that waits for its link would read lost, so the apply in flight
/// or failed for this pad speaks first (B6); a done one leaves the PC's
/// own line.
private func rowLine(_ controller: ControllerFact, apply: ApplyFact?, port: DevicePort, words: L10n) -> RowLine {
    guard let apply, apply.slotId == controller.id else { return pcLine(controller, port: port, words: words) }
    switch apply.progress {
    case .running: return RowLine(destination: .note(words.applyingBinding), mark: .busy)
    case let .failed(failure): return RowLine(destination: .note(applyFailureText(failure, words: words)), mark: .dot(DishTheme.error))
    case .idle, .done: return pcLine(controller, port: port, words: words)
    }
}

private func pcLine(_ controller: ControllerFact, port: DevicePort, words: L10n) -> RowLine {
    RowLine(destination: destinationLine(controller, port: port, words: words), mark: destinationMark(controller.destination?.health))
}

/// A pad's own name; the on-screen controller is worded here.
func controllerName(_ controller: ControllerFact, words: L10n = .app) -> String {
    switch controller.link {
    case .usbC, .bluetooth: controller.name
    case .onScreen: words.onScreenGamepad
    }
}

/// Only the on-screen controller has a gamepad to open, once it is bound.
func opensGamepad(_ controller: ControllerFact) -> Bool {
    controller.link == .onScreen && controller.destination != nil
}

func controllerSymbol(_ link: ControllerLink) -> String {
    switch link {
    case .usbC, .bluetooth: "gamecontroller"
    case .onScreen: "iphone"
    }
}

/// A pad attached to the device is worded by the device's port.
func linkWord(_ link: ControllerLink, port: DevicePort = .usbC, words: L10n = .app) -> String {
    switch link {
    case .usbC: wiredLinkWord(port, words: words)
    case .bluetooth: words.linkBluetooth
    case .onScreen: words.linkOnScreen
    }
}

/// The link word while the PC answers; a PC being reached for says so in
/// its place, and a lost one replaces the whole line, as D4 draws it.
private func destinationLine(_ controller: ControllerFact, port: DevicePort, words: L10n) -> DestinationLine {
    guard controller.supported else { return .note(words.notSupported) }
    guard let destination = controller.destination else { return .note(words.notBound) }
    switch destination.health {
    case .online: return .bound(pcName: destination.name, detail: lineSeparator + linkWord(controller.link, port: port, words: words))
    case .connecting: return .bound(pcName: destination.name, detail: lineSeparator + words.connecting)
    case .lost: return .note(words.connectionLost)
    }
}

/// The dot of the PC's health, or the spinner while it is being reached for.
func destinationMark(_ health: LinkHealth?) -> StatusMark {
    switch health {
    case .online: .dot(DishTheme.success)
    case .connecting: .busy
    case .lost: .dot(DishTheme.error)
    case nil: .dot(DishTheme.muted)
    }
}

/// The health as a colour alone, for a card that draws no spinner.
func destinationDot(_ health: LinkHealth?) -> Color {
    switch health {
    case .online: DishTheme.success
    case .connecting: DishTheme.warning
    case .lost: DishTheme.error
    case nil: DishTheme.muted
    }
}

private func batteryColor(_ percent: Int?) -> Color {
    let low = percent.map { $0 <= lowBatteryPercent } ?? false
    return low ? DishTheme.error : DishTheme.muted
}
