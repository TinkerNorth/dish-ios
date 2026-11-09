// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation
import Observation

/// The composition root: it holds every store and vends the facts the shell
/// draws. Intents live in extensions by topic and are the only thing a view
/// calls. Controllers, connections and the session have no source yet, so
/// their facts are real and empty.
@MainActor
@Observable
package final class AppModel {
    package let onboarding: OnboardingPreferenceStore
    let appearance: AppearancePreferenceStore
    let device: DevicePreferenceStore
    let streaming: StreamingPreferenceStore
    let clock: ClockSource

    package init(
        onboarding: OnboardingPreferenceStore,
        appearance: AppearancePreferenceStore,
        device: DevicePreferenceStore,
        streaming: StreamingPreferenceStore,
        clock: ClockSource
    ) {
        self.onboarding = onboarding
        self.appearance = appearance
        self.device = device
        self.streaming = streaming
        self.clock = clock
    }

    /// Every store over the same defaults, and the wall clock.
    package convenience init(defaults: UserDefaults) {
        self.init(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: TimerTicker(), now: Date.init)
        )
    }

    package var shellFacts: ShellFacts {
        ShellFacts(
            controllers: [],
            paired: [],
            found: [],
            scanning: false,
            session: nil,
            localNetwork: .unknown,
            preferences: preferencesFacts,
            now: clock.state
        )
    }

    private var preferencesFacts: PreferencesFacts {
        let streaming = streaming.state
        return PreferencesFacts(
            deviceName: device.state,
            keepScreenOn: streaming.keepScreenOn,
            dimAfter: streaming.dimAfter,
            appearance: appearance.state
        )
    }
}
