// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// Whether the first-run welcome has been seen, and whether the Local
/// Network primer has. Skipping and binding both complete the welcome, so
/// the setup cover rises on its own exactly once.
package struct OnboardingPreferences: Equatable {
    package var welcomeCompleted: Bool
    /// Whether the Local Network primer has been seen, so iOS's question is
    /// asked after the explanation and the Connections tab's own scan may run.
    package var localNetworkPrimed: Bool

    package init(welcomeCompleted: Bool, localNetworkPrimed: Bool = false) {
        self.welcomeCompleted = welcomeCompleted
        self.localNetworkPrimed = localNetworkPrimed
    }
}

/// The onboarding flag, straight over `UserDefaults` under the fleet's key.
/// The setter persists and republishes, and is idempotent: a repeat set does
/// not re-emit, so a subscriber cannot loop through its own write.
@MainActor
package final class OnboardingPreferenceStore {
    static let welcomeCompletedKey = "onboarding_welcome_completed"
    static let localNetworkPrimedKey = "local_network_primed"

    private let defaults: UserDefaults
    private let source: StateSource<OnboardingPreferences>

    package var state: OnboardingPreferences {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = OnboardingPreferences(
            welcomeCompleted: defaults.bool(forKey: Self.welcomeCompletedKey),
            localNetworkPrimed: defaults.bool(forKey: Self.localNetworkPrimedKey)
        )
        source = StateSource(initial: stored)
    }

    package func markWelcomeComplete() {
        guard !state.welcomeCompleted else { return }
        defaults.set(true, forKey: Self.welcomeCompletedKey)
        source.updateState { $0.with(welcomeCompleted: true) }
    }

    package func markLocalNetworkPrimed() {
        guard !state.localNetworkPrimed else { return }
        defaults.set(true, forKey: Self.localNetworkPrimedKey)
        source.updateState { $0.with(localNetworkPrimed: true) }
    }
}

extension OnboardingPreferences {
    func with(welcomeCompleted: Bool) -> OnboardingPreferences {
        OnboardingPreferences(welcomeCompleted: welcomeCompleted, localNetworkPrimed: localNetworkPrimed)
    }

    func with(localNetworkPrimed: Bool) -> OnboardingPreferences {
        OnboardingPreferences(welcomeCompleted: welcomeCompleted, localNetworkPrimed: localNetworkPrimed)
    }
}
