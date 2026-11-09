// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// Dish's page in the Settings app, handed down by the scene so no view
/// reads UIKit for it. Nil leaves Open Settings out.
private struct SettingsURLKey: EnvironmentKey {
    static let defaultValue: URL? = nil
}

/// The bundle's short version, handed down by the scene.
private struct AppVersionKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var settingsURL: URL? {
        get { self[SettingsURLKey.self] }
        set { self[SettingsURLKey.self] = newValue }
    }

    var appVersion: String {
        get { self[AppVersionKey.self] }
        set { self[AppVersionKey.self] = newValue }
    }
}
