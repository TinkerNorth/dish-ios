// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Light, dark or the system's, stored under the fleet's `theme_mode` with
/// dish-mac's `ThemeMode` raw values.
package enum Appearance: String, CaseIterable, Equatable {
    case system
    case light
    case dark
}

/// How long the screen stays lit while streaming before Dish dims it,
/// stored as seconds; `never` is zero.
package enum DimDelay: Int, CaseIterable, Equatable {
    case tenSeconds = 10
    case twentySeconds = 20
    case thirtySeconds = 30
    case oneMinute = 60
    case twoMinutes = 120
    case never = 0
}

/// The settings the shell reads.
package struct PreferencesFacts: Equatable {
    /// The name Satellite sees; empty means the system's ("iPhone").
    package let deviceName: String
    package let keepScreenOn: Bool
    package let dimAfter: DimDelay
    package let appearance: Appearance

    package init(deviceName: String, keepScreenOn: Bool, dimAfter: DimDelay, appearance: Appearance) {
        self.deviceName = deviceName
        self.keepScreenOn = keepScreenOn
        self.dimAfter = dimAfter
        self.appearance = appearance
    }
}
