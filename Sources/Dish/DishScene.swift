// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI
import UIKit

/// The one scene. The composition root's objects are made here once and
/// handed to the shell as environment values. It is not a view: the clock,
/// the defaults and UIKit's shared objects are allowed here and nowhere
/// under `UI/`.
@MainActor
public struct DishScene: Scene {

    @State private var model: AppModel
    @State private var navigation: NavigationStore

    public init() {
        let model = AppModel(defaults: .standard)
        _model = State(initialValue: model)
        let navigation = NavigationStore(
            onboarding: model.onboarding,
            startSetup: { model.startSetup(setupStart($0)) },
            endSetup: model.endSetup
        )
        _navigation = State(initialValue: navigation)
    }

    public var body: some Scene {
        WindowGroup {
            ShellView()
                .environment(model)
                .environment(navigation)
                .environment(\.settingsURL, URL(string: UIApplication.openSettingsURLString))
                .environment(\.appVersion, shortVersion(of: .main))
                .preferredColorScheme(colorScheme(for: model.shellFacts.preferences.appearance))
                .onChange(of: idleTimerDisabled(facts: model.shellFacts), initial: true) { holdScreenOn($1) }
        }
    }

    /// iOS locks the screen and suspends Dish unless the idle timer is off.
    private func holdScreenOn(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}

/// The bundle's marketing version, empty when the bundle carries none.
private func shortVersion(of bundle: Bundle) -> String {
    bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
}
