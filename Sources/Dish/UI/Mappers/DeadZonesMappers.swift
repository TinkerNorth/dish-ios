// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation

/// One slider of the Dead zones page: its label, the percent it stands at,
/// the readout beside it and the travel.
struct DeadZoneSliderState: Equatable {
    let label: String
    let percent: Int
    let readout: String
    let maxPercent: Int

    /// The slider's position and travel.
    var value: Double {
        Double(percent)
    }

    var travel: ClosedRange<Double> {
        0 ... Double(maxPercent)
    }
}

/// The card of a pad that is attached.
struct DeadZonesCardState: Equatable {
    let stick: DeadZoneSliderState
    let trigger: DeadZoneSliderState
    let reset: String
    /// What Reset says to VoiceOver: whose dead zones it resets.
    let resetHint: String
}

enum DeadZonesContent: Equatable {
    case pad(DeadZonesCardState)
    /// The pad left while its page was open.
    case gone(message: String)
}

/// A controller's Dead zones page.
struct DeadZonesPageState: Equatable {
    let title: String
    /// The pad's name; empty while the pad is away.
    let subtitle: String
    let content: DeadZonesContent
    let footnote: String
}

func deadZonesPageState(
    id: String,
    controllers: [ControllerFact],
    zones: [String: DeadzoneSetting],
    words: L10n = .app
) -> DeadZonesPageState {
    let footnote = words.overridesArePerDevice
    guard let controller = controllers.first(where: { $0.id == id }) else {
        return DeadZonesPageState(title: words.deadZones, subtitle: "", content: .gone(message: words.controllerGone), footnote: footnote)
    }
    let name = controllerName(controller, words: words)
    let setting = zones[id] ?? .defaults
    let card = DeadZonesCardState(
        stick: deadZoneSlider(words.stickDeadZone, percent: setting.stickPercent, words: words),
        trigger: deadZoneSlider(words.triggerDeadZone, percent: setting.triggerPercent, words: words),
        reset: words.resetToDefaults,
        resetHint: words.resetDeadZonesFor(name)
    )
    return DeadZonesPageState(title: words.deadZones, subtitle: name, content: .pad(card), footnote: footnote)
}

private func deadZoneSlider(_ label: String, percent: Int, words: L10n) -> DeadZoneSliderState {
    DeadZoneSliderState(label: label, percent: percent, readout: words.percent(percent), maxPercent: DeadzoneSetting.maxPercent)
}
