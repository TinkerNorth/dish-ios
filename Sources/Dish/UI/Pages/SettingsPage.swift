// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// What the Settings rows do: each one an intent or a navigation event.
struct SettingsActions {
    let editDeviceName: @MainActor () -> Void
    let openGuide: @MainActor () -> Void
    let openHelp: @MainActor () -> Void
    let openSupport: @MainActor () -> Void
    let openLicenses: @MainActor () -> Void
    let open: @MainActor (URL?) -> Void
    let setKeepScreenOn: @MainActor (Bool) -> Void
    let setDimAfter: @MainActor (DimDelay) -> Void
    let setAppearance: @MainActor (Appearance) -> Void
}

/// The Settings tab (D5). Diagnostics comes with its page.
struct SettingsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation
    @Environment(\.appVersion) private var appVersion
    @Environment(\.openURL) private var openURL

    var body: some View {
        SettingsPageBody(
            state: settingsPageState(preferences: model.shellFacts.preferences, appVersion: appVersion),
            actions: SettingsActions(
                editDeviceName: editDeviceName,
                openGuide: openGuide,
                openHelp: { push(.help) },
                openSupport: { push(.support) },
                openLicenses: { push(.licenses) },
                open: open,
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

    private func push(_ page: Page) {
        navigation.send(.push(page))
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
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
            SetupHelpSection(state: state.help, actions: actions)
            AppearanceSection(state: state.appearance, select: actions.setAppearance)
            AboutSection(state: state.about, actions: actions)
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
                openHelp: {},
                openSupport: {},
                openLicenses: {},
                open: { _ in },
                setKeepScreenOn: { _ in },
                setDimAfter: { _ in },
                setAppearance: { _ in }
            )
        )
    }
}
