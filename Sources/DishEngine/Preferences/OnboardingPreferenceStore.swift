// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// Whether the first-run welcome has been seen. Skipping and binding both
/// complete it, so the setup cover rises on its own exactly once.
package struct OnboardingPreferences: Equatable {
    package var welcomeCompleted: Bool

    package init(welcomeCompleted: Bool) {
        self.welcomeCompleted = welcomeCompleted
    }
}

/// The onboarding flag, straight over `UserDefaults` under the fleet's key.
/// The setter persists and republishes, and is idempotent: a repeat set does
/// not re-emit, so a subscriber cannot loop through its own write.
@MainActor
package final class OnboardingPreferenceStore {
    static let welcomeCompletedKey = "onboarding_welcome_completed"

    private let defaults: UserDefaults
    private let source: StateSource<OnboardingPreferences>

    package var state: OnboardingPreferences {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = defaults.bool(forKey: Self.welcomeCompletedKey)
        source = StateSource(initial: OnboardingPreferences(welcomeCompleted: stored))
    }

    package func markWelcomeComplete() {
        guard !state.welcomeCompleted else { return }
        defaults.set(true, forKey: Self.welcomeCompletedKey)
        source.setState(OnboardingPreferences(welcomeCompleted: true))
    }
}
