// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What the Dead zones page's controls do: each one an intent.
struct DeadZonesActions {
    let setStick: @MainActor (Double) -> Void
    let setTrigger: @MainActor (Double) -> Void
    let reset: @MainActor () -> Void

    /// Controls that do nothing, for a preview.
    @MainActor static let preview = DeadZonesActions(setStick: { _ in }, setTrigger: { _ in }, reset: {})
}

/// Controllers › a controller › Dead zones: the stick and trigger flats as
/// sliders, applied to the pad as they move, and Reset to the defaults.
struct DeadZonesPage: View {
    let id: String

    @Environment(AppModel.self) private var model

    var body: some View {
        DeadZonesPageBody(
            state: deadZonesPageState(id: id, controllers: model.shellFacts.controllers, zones: model.shellFacts.deadzones),
            actions: DeadZonesActions(setStick: setStick, setTrigger: setTrigger, reset: reset)
        )
    }

    private func setStick(_ percent: Double) {
        model.setStickDeadzone(percent: Int(percent), slotId: id)
    }

    private func setTrigger(_ percent: Double) {
        model.setTriggerDeadzone(percent: Int(percent), slotId: id)
    }

    private func reset() {
        model.resetDeadzones(slotId: id)
    }
}

/// The page over its state, so a preview can draw every state.
struct DeadZonesPageBody: View {
    let state: DeadZonesPageState
    let actions: DeadZonesActions

    var body: some View {
        List {
            switch state.content {
            case let .pad(card):
                Section {
                    DeadZoneSlider(state: card.stick, change: actions.setStick)
                    DeadZoneSlider(state: card.trigger, change: actions.setTrigger)
                    Button(card.reset, action: actions.reset)
                        .accessibilityLabel(card.resetHint)
                } footer: {
                    Text(state.footnote).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                }
                .listRowBackground(DishTheme.surface)
            case let .gone(message):
                ContentUnavailableView(state.title, systemImage: "gamecontroller", description: Text(message))
                    .listRowBackground(EmptyView())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationSubtitle(state.subtitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A label and its readout over a slider across the desktops' travel.
private struct DeadZoneSlider: View {
    let state: DeadZoneSliderState
    let change: @MainActor (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s3) {
            LabeledContent(state.label) {
                Text(state.readout).font(DishFont.mono)
            }
            .foregroundStyle(DishTheme.onSurface)
            Slider(value: Binding(get: { state.value }, set: { change($0) }), in: state.travel, step: 1)
                .tint(DishTheme.primary)
                .accessibilityLabel(state.label)
                .accessibilityValue(state.readout)
        }
        .padding(.vertical, DishSpace.s2)
    }
}

#Preview("Tuned") {
    let pad = ControllerFact(id: "pad", name: "DualSense", link: .usbC, batteryPercent: 84, destination: nil)
    let tuned = DeadzoneSetting(stickPercent: 18, triggerPercent: 8)
    NavigationStack {
        DeadZonesPageBody(
            state: deadZonesPageState(id: "pad", controllers: [pad], zones: ["pad": tuned]),
            actions: .preview
        )
    }
}

#Preview("Gone") {
    NavigationStack {
        DeadZonesPageBody(state: deadZonesPageState(id: "pad", controllers: [], zones: [:]), actions: .preview)
    }
}
