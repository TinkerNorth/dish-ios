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

/// What a controller row's menu, swipes and Open do.
enum ControllerRowAction: Hashable {
    /// The on-screen controller's gamepad.
    case open
    case bind(slotId: String, connectionId: String)
    case unbind(slotId: String)
}

/// One controller row (A2).
struct ControllerRowState: Equatable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let destination: DestinationLine
    let dot: Color
    /// Nil when the controller reports no level.
    let battery: String?
    let batteryColor: Color
    /// The controller's page; nil for a pad Dish cannot read, which has
    /// nothing to set.
    let page: Page?
    /// The on-screen controller's Open, which raises its gamepad; nil for a pad.
    let open: String?
    /// The long-press menu and the swipes.
    let actions: RowActionsState<ControllerRowAction>
}

/// What sits above the Add button: the rows, or an invitation.
enum ControllersContent: Equatable {
    case empty(invitation: String)
    case list([ControllerRowState])
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
    let content: ControllersContent
    let addTitle: String
    let addHint: String
    /// The heart on the toolbar: Support Dish.
    let support: ToolbarLinkState
    let hints: ControllersHints
}

/// The level at and below which a battery reads in the error colour.
private let lowBatteryPercent = 15

/// `apply` is the bind in flight or just ended, which speaks on its pad's
/// row in place of the destination; `paired` are the PCs a row's Bind to
/// offers.
func controllersPageState(
    controllers: [ControllerFact],
    apply: ApplyFact? = nil,
    paired: [ConnectionFact] = [],
    words: L10n = .app
) -> ControllersPageState {
    ControllersPageState(
        title: words.controllers,
        content: controllersContent(controllers, apply: apply, paired: paired, words: words),
        addTitle: words.addAController,
        addHint: words.addAControllerHint,
        support: ToolbarLinkState(title: words.supportDish, symbol: heartSymbol, page: .support),
        hints: controllersHints(listed: !controllers.isEmpty, words: words)
    )
}

/// The heart's hint waits until a controller is listed, so a new person
/// meets Add a controller's first.
private func controllersHints(listed: Bool, words: L10n) -> ControllersHints {
    ControllersHints(support: listed ? hintState(.supportDish, words: words) : nil, add: hintState(.addController, words: words))
}

private func controllersContent(
    _ controllers: [ControllerFact],
    apply: ApplyFact?,
    paired: [ConnectionFact],
    words: L10n
) -> ControllersContent {
    guard !controllers.isEmpty else { return .empty(invitation: words.noControllersInvitation) }
    return .list(controllers.map { controllerRow($0, apply: apply, paired: paired, words: words) })
}

func controllerRow(
    _ controller: ControllerFact,
    apply: ApplyFact? = nil,
    paired: [ConnectionFact] = [],
    words: L10n = .app
) -> ControllerRowState {
    let line = rowLine(controller, apply: apply, words: words)
    return ControllerRowState(
        id: controller.id,
        symbol: controllerSymbol(controller.link),
        name: controllerName(controller, words: words),
        destination: line.destination,
        dot: line.dot,
        battery: controller.batteryPercent.map(words.batteryPercent),
        batteryColor: batteryColor(controller.batteryPercent),
        page: controller.supported ? .controller(id: controller.id) : nil,
        open: opensPlay(controller.link) ? words.open : nil,
        actions: controllerRowActions(controller, paired: paired, words: words)
    )
}

/// Open for the on-screen controller, also under a swipe from the leading
/// edge; Unbind for a bound controller, also under a swipe from the
/// trailing edge, or Bind to with each paired PC for an unbound one. A pad
/// Dish cannot read offers nothing.
func controllerRowActions(
    _ controller: ControllerFact,
    paired: [ConnectionFact],
    words: L10n = .app
) -> RowActionsState<ControllerRowAction> {
    guard controller.supported else { return .none }
    let open = opensPlay(controller.link) ? [openItem(words: words)] : []
    switch controller.destination {
    case .some: return boundActions(controller.id, open: open, words: words)
    case nil: return unboundActions(controller.id, open: open, paired: paired, words: words)
    }
}

private func openItem(words: L10n) -> RowActionItem<ControllerRowAction> {
    RowActionItem(action: .open, title: words.open, symbol: RowActionSymbol.open, destructive: false)
}

private func boundActions(
    _ slotId: String,
    open: [RowActionItem<ControllerRowAction>],
    words: L10n
) -> RowActionsState<ControllerRowAction> {
    let unbind = RowActionItem(
        action: ControllerRowAction.unbind(slotId: slotId),
        title: words.unbind,
        symbol: RowActionSymbol.unbind,
        destructive: true
    )
    return RowActionsState(menu: (open + [unbind]).map(RowMenuEntry.item), leading: open, trailing: [unbind])
}

/// Bind to is a submenu of the paired PCs; with none paired there is
/// nothing to bind to.
private func unboundActions(
    _ slotId: String,
    open: [RowActionItem<ControllerRowAction>],
    paired: [ConnectionFact],
    words: L10n
) -> RowActionsState<ControllerRowAction> {
    let choices = paired.map { pc in
        RowActionItem(
            action: ControllerRowAction.bind(slotId: slotId, connectionId: pc.id),
            title: connectionTitle(pc),
            symbol: connectionSymbol(pc.kind),
            destructive: false
        )
    }
    let bindTo = choices.isEmpty ? [] : [RowMenuEntry.submenu(title: words.bindTo, symbol: RowActionSymbol.bind, items: choices)]
    return RowActionsState(menu: open.map(RowMenuEntry.item) + bindTo, leading: open, trailing: [])
}

/// A row's second line and its dot.
private struct RowLine {
    let destination: DestinationLine
    let dot: Color
}

/// A bind that waits for its link would read lost, so the apply in flight
/// or failed for this pad speaks first (B6); a done one leaves the PC's
/// own line.
private func rowLine(_ controller: ControllerFact, apply: ApplyFact?, words: L10n) -> RowLine {
    guard let apply, apply.slotId == controller.id else { return pcLine(controller, words: words) }
    switch apply.progress {
    case .running: return RowLine(destination: .note(words.applyingBinding), dot: DishTheme.muted)
    case let .failed(failure): return RowLine(destination: .note(applyFailureText(failure, words: words)), dot: DishTheme.error)
    case .idle, .done: return pcLine(controller, words: words)
    }
}

private func pcLine(_ controller: ControllerFact, words: L10n) -> RowLine {
    RowLine(destination: destinationLine(controller, words: words), dot: destinationDot(controller.destination?.health))
}

/// A pad's own name; the on-screen controller is worded here.
func controllerName(_ controller: ControllerFact, words: L10n = .app) -> String {
    switch controller.link {
    case .usbC, .bluetooth: controller.name
    case .onScreen: words.onScreenGamepad
    }
}

/// Only the on-screen controller has a screen to open.
func opensPlay(_ link: ControllerLink) -> Bool {
    switch link {
    case .usbC, .bluetooth: false
    case .onScreen: true
    }
}

func controllerSymbol(_ link: ControllerLink) -> String {
    switch link {
    case .usbC, .bluetooth: "gamecontroller"
    case .onScreen: "iphone"
    }
}

func linkWord(_ link: ControllerLink, words: L10n = .app) -> String {
    switch link {
    case .usbC: words.linkUsbC
    case .bluetooth: words.linkBluetooth
    case .onScreen: words.linkOnScreen
    }
}

/// The link word while the PC answers; an unsteady PC says so in its place,
/// and a lost one replaces the whole line, as D4 draws it.
private func destinationLine(_ controller: ControllerFact, words: L10n) -> DestinationLine {
    guard controller.supported else { return .note(words.notSupported) }
    guard let destination = controller.destination else { return .note(words.notBound) }
    switch destination.health {
    case .online: return .bound(pcName: destination.name, detail: lineSeparator + linkWord(controller.link, words: words))
    case .unsteady: return .bound(pcName: destination.name, detail: lineSeparator + words.unsteady)
    case .lost: return .note(words.connectionLost)
    }
}

func destinationDot(_ health: LinkHealth?) -> Color {
    switch health {
    case .online: DishTheme.success
    case .unsteady: DishTheme.warning
    case .lost: DishTheme.error
    case nil: DishTheme.muted
    }
}

private func batteryColor(_ percent: Int?) -> Color {
    let low = percent.map { $0 <= lowBatteryPercent } ?? false
    return low ? DishTheme.error : DishTheme.muted
}
