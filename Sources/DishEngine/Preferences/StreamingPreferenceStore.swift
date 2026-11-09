// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// What Dish does with the screen while it forwards a controller.
package struct StreamingPreferences: Equatable {
    package var keepScreenOn: Bool
    package var dimAfter: DimDelay

    package init(keepScreenOn: Bool, dimAfter: DimDelay) {
        self.keepScreenOn = keepScreenOn
        self.dimAfter = dimAfter
    }
}

/// Keep screen on and Dim screen after, over `UserDefaults`. A missing or
/// unknown stored value reads as the fresh-install one; the setters are
/// idempotent.
@MainActor
package final class StreamingPreferenceStore {
    static let keepScreenOnKey = "keep_screen_on"
    static let dimAfterKey = "dim_after_seconds"
    /// A fresh install's values, and what an unreadable stored value reads as.
    static let fallback = StreamingPreferences(keepScreenOn: true, dimAfter: .twentySeconds)

    private let defaults: UserDefaults
    private let source: StateSource<StreamingPreferences>

    package var state: StreamingPreferences {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        let keepScreenOn = defaults.object(forKey: Self.keepScreenOnKey) as? Bool ?? Self.fallback.keepScreenOn
        let storedSeconds = defaults.object(forKey: Self.dimAfterKey) as? Int
        let dimAfter = storedSeconds.flatMap(DimDelay.init(rawValue:)) ?? Self.fallback.dimAfter
        source = StateSource(initial: StreamingPreferences(keepScreenOn: keepScreenOn, dimAfter: dimAfter))
    }

    package func setKeepScreenOn(_ enabled: Bool) {
        guard enabled != state.keepScreenOn else { return }
        defaults.set(enabled, forKey: Self.keepScreenOnKey)
        source.updateState { StreamingPreferences(keepScreenOn: enabled, dimAfter: $0.dimAfter) }
    }

    package func setDimAfter(_ delay: DimDelay) {
        guard delay != state.dimAfter else { return }
        defaults.set(delay.rawValue, forKey: Self.dimAfterKey)
        source.updateState { StreamingPreferences(keepScreenOn: $0.keepScreenOn, dimAfter: delay) }
    }
}
