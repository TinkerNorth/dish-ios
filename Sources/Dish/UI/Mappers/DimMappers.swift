// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// One controller on the dim's session card: its name and its level.
struct DimPadRow: Equatable, Identifiable {
    let id: String
    let name: String
    let battery: String
}

/// The dim's session card: the PC, the session line the accessory shows,
/// and the bound controllers that report a level.
struct DimCardState: Equatable {
    let pcName: String
    let line: String
    let dot: Color
    let lineColor: Color
    let pads: [DimPadRow]
}

/// C5, the low-power dim.
struct DimCoverState: Equatable {
    let eyebrow: String
    let clock: String
    /// Nil while no session is up.
    let card: DimCardState?
    let wake: String
    let footnote: String
}

func dimCoverState(facts: ShellFacts, words: L10n = .app) -> DimCoverState {
    DimCoverState(
        eyebrow: words.lowPower,
        clock: dimClock(facts.now),
        card: dimCard(facts, words: words),
        wake: words.tapToWake,
        footnote: words.dimFootnote
    )
}

/// The time as the person's locale writes it, hours and minutes.
func dimClock(_ now: Date) -> String {
    now.formatted(date: .omitted, time: .shortened)
}

/// The card carries the accessory's own line, so the two never disagree.
private func dimCard(_ facts: ShellFacts, words: L10n) -> DimCardState? {
    guard let bar = sessionBarState(facts.session, words: words) else { return nil }
    let pads = facts.controllers.compactMap { dimPadRow($0, words: words) }
    switch bar {
    case let .streaming(pcName, line, _, _, _):
        return DimCardState(pcName: pcName, line: line, dot: DishTheme.success, lineColor: DishTheme.dimText, pads: pads)
    case let .problem(pcName, line, _):
        return DimCardState(pcName: pcName, line: line, dot: DishTheme.error, lineColor: DishTheme.error, pads: pads)
    }
}

/// A bound controller with a level; the rest are left off the card.
private func dimPadRow(_ controller: ControllerFact, words: L10n) -> DimPadRow? {
    guard controller.destination != nil, let percent = controller.batteryPercent else { return nil }
    return DimPadRow(id: controller.id, name: controllerName(controller, words: words), battery: words.batteryPercent(percent))
}
