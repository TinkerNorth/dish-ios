// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import UIKit

/// The app delegate UIKit asks which ways the window may turn. It answers
/// with the mask the scene last set from the navigation: portrait, or
/// landscape while a play cover is up. The `@main` app declares it with
/// `@UIApplicationDelegateAdaptor`, the only way SwiftUI hands UIKit a
/// delegate, and passes it to `DishScene`, which alone turns the window.
@MainActor
public final class OrientationLock: NSObject, UIApplicationDelegate {
    var mask = UIInterfaceOrientationMask.portrait

    override public init() {
        super.init()
    }

    public func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        mask
    }
}

/// The window's mask for an orientation.
func interfaceMask(_ orientation: ScreenOrientation) -> UIInterfaceOrientationMask {
    switch orientation {
    case .portrait: .portrait
    case .landscape: .landscape
    }
}
