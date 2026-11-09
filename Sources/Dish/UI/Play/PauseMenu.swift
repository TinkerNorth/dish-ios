// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// What a play screen's controls and its pause menu do: each one an intent.
struct PlayActions {
    let pad: @MainActor (OnScreenPadEvent) -> Void
    let touch: @MainActor (TouchSurfaceEvent) -> Void
    let open: @MainActor (PlayScreen) -> Void
    let setRumble: @MainActor (Bool) -> Void
    let setMotion: @MainActor (Bool) -> Void
    let setEmulateAs: @MainActor (EmulatedPad) -> Void
    let stop: @MainActor () -> Void
}

/// C3: the pause button and its native menu. Resume closes the menu, the
/// other screens are a tap away, Motion and Rumble are toggles, Emulate as
/// a picker, and Stop gamepad is the destructive way out.
struct PauseMenu: View {
    let state: PauseMenuState
    let actions: PlayActions

    var body: some View {
        Menu {
            Button(state.resume, systemImage: PlaySymbol.resume) {}
            Section {
                ForEach(state.screens) { item in
                    Button(item.title, systemImage: item.symbol) { actions.open(item.screen) }
                }
            }
            if let switches = state.switches {
                PauseSwitches(state: switches, actions: actions)
            }
            Section {
                Button(state.stop, systemImage: PlaySymbol.stop, role: .destructive) { actions.stop() }
            }
        } label: {
            Image(systemName: PlaySymbol.pause)
                .font(DishFont.headline)
                .foregroundStyle(DishTheme.onSurface)
                .frame(width: DishSize.padRound, height: DishSize.padRound)
                .background(Circle().fill(DishTheme.surface))
                .overlay(Circle().stroke(DishTheme.outline, lineWidth: DishSize.padStroke))
        }
        .accessibilityLabel(state.title)
    }
}

/// The gamepad's section: Motion (disabled with its reason when the pad or
/// the phone has none), Rumble and Emulate as.
private struct PauseSwitches: View {
    let state: PauseSwitchesState
    let actions: PlayActions

    var body: some View {
        Section {
            PauseToggle(state: state.motion, set: actions.setMotion)
            PauseToggle(state: state.rumble, set: actions.setRumble)
            Picker(selection: Binding(get: { state.emulateAs }, set: { actions.setEmulateAs($0) })) {
                ForEach(state.emulateOptions) { Text($0.name).tag($0.pad) }
            } label: {
                Label(state.emulateTitle, systemImage: state.emulateSymbol)
            }
            .pickerStyle(.menu)
        }
    }
}

private struct PauseToggle: View {
    let state: PauseToggleState
    let set: @MainActor (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { state.isOn }, set: { set($0) })) {
            Label(state.title, systemImage: state.symbol)
            if let reason = state.reason {
                Text(reason)
            }
        }
        .disabled(!state.enabled)
    }
}
