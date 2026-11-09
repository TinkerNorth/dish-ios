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

/// The Controllers tab.
struct ControllersPageState: Equatable {
    let title: String
    let content: ControllersContent
    let addTitle: String
    let addHint: String
    /// The heart on the toolbar: Support Dish.
    let support: ToolbarLinkState
}

/// The level at and below which a battery reads in the error colour.
private let lowBatteryPercent = 15

func controllersPageState(controllers: [ControllerFact], words: L10n = .app) -> ControllersPageState {
    ControllersPageState(
        title: words.controllers,
        content: controllersContent(controllers, words: words),
        addTitle: words.addAController,
        addHint: words.addAControllerHint,
        support: ToolbarLinkState(title: words.supportDish, symbol: heartSymbol, page: .support)
    )
}

private func controllersContent(_ controllers: [ControllerFact], words: L10n) -> ControllersContent {
    guard !controllers.isEmpty else { return .empty(invitation: words.noControllersInvitation) }
    return .list(controllers.map { controllerRow($0, words: words) })
}

func controllerRow(_ controller: ControllerFact, words: L10n = .app) -> ControllerRowState {
    ControllerRowState(
        id: controller.id,
        symbol: controllerSymbol(controller.link),
        name: controllerName(controller, words: words),
        destination: destinationLine(controller, words: words),
        dot: destinationDot(controller.destination?.health),
        battery: controller.batteryPercent.map(words.batteryPercent),
        batteryColor: batteryColor(controller.batteryPercent),
        page: controller.supported ? .controller(id: controller.id) : nil,
        open: opensPlay(controller.link) ? words.open : nil
    )
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
