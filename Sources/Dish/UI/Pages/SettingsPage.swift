// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// What the Settings rows do: each one an intent or a navigation event.
struct SettingsActions {
    let editDeviceName: @MainActor () -> Void
    let openGuide: @MainActor () -> Void
    let setKeepScreenOn: @MainActor (Bool) -> Void
    let setDimAfter: @MainActor (DimDelay) -> Void
    let setAppearance: @MainActor (Appearance) -> Void
}

/// The Settings tab (D5). Help & FAQ, Diagnostics and Support Dish come
/// with their pages.
struct SettingsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation
    @Environment(\.appVersion) private var appVersion

    var body: some View {
        SettingsPageBody(
            state: settingsPageState(preferences: model.shellFacts.preferences, appVersion: appVersion),
            actions: SettingsActions(
                editDeviceName: editDeviceName,
                openGuide: openGuide,
                setKeepScreenOn: model.setKeepScreenOn,
                setDimAfter: model.setDimAfter,
                setAppearance: model.setAppearance
            )
        )
    }

    private func editDeviceName() {
        navigation.send(.push(.deviceName))
    }

    private func openGuide() {
        navigation.send(.openSetup(.guide))
    }
}

/// The page over its state, so a preview can draw it.
struct SettingsPageBody: View {
    let state: SettingsPageState
    let actions: SettingsActions

    var body: some View {
        List {
            DeviceSection(state: state.device, edit: actions.editDeviceName)
            StreamingSection(state: state.streaming, actions: actions)
            HelpSection(state: state.help, openGuide: actions.openGuide)
            AppearanceSection(state: state.appearance, select: actions.setAppearance)
            AboutSection(state: state.about)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview("Settings") {
    let preferences = PreferencesFacts(deviceName: "", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system)
    NavigationStack {
        SettingsPageBody(
            state: settingsPageState(preferences: preferences, appVersion: "0.1.0"),
            actions: SettingsActions(
                editDeviceName: {},
                openGuide: {},
                setKeepScreenOn: { _ in },
                setDimAfter: { _ in },
                setAppearance: { _ in }
            )
        )
    }
}
