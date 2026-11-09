// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The Settings tab's intents.
package extension AppModel {
    func setDeviceName(_ name: String) {
        device.setDeviceName(name)
    }

    func setKeepScreenOn(_ enabled: Bool) {
        streaming.setKeepScreenOn(enabled)
    }

    func setDimAfter(_ delay: DimDelay) {
        streaming.setDimAfter(delay)
    }

    func setAppearance(_ appearance: Appearance) {
        self.appearance.setAppearance(appearance)
    }
}
