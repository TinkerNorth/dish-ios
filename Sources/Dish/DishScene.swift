// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// The one scene. The composition root's objects are made here once and
/// handed to the shell as environment values. It is not a view: the clock,
/// the defaults and UIKit's shared objects are allowed here and nowhere
/// under `UI/`.
@MainActor
public struct DishScene: Scene {

    @State private var navigation = NavigationStore(
        onboarding: OnboardingPreferenceStore(defaults: .standard),
        startSetup: { _ in },
        endSetup: {}
    )

    public init() {}

    public var body: some Scene {
        WindowGroup {
            DishTheme.background
                .ignoresSafeArea()
                .environment(navigation)
        }
    }
}
