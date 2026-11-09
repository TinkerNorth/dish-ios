// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Dish
import SwiftUI

/// The app is its scene. Everything else is the `Dish` package beside this
/// target, which adds the icon, the Info.plist and the entitlements. The
/// orientation lock is the one app delegate, and SwiftUI only takes one
/// from the `App` itself.
@main
struct DishApp: App {
    @UIApplicationDelegateAdaptor(OrientationLock.self) private var orientation

    var body: some Scene {
        DishScene(orientation: orientation)
    }
}
