// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import UIKit

/// The app delegate UIKit asks which ways the window may turn. It answers
/// with the mask the scene last set from the navigation and the device: on
/// an iPhone portrait, or landscape while a play cover is up; on an iPad
/// every way. The `@main` app declares it with `@UIApplicationDelegateAdaptor`,
/// the only way SwiftUI hands UIKit a delegate, and passes it to `DishScene`,
/// which alone turns the window.
@MainActor
public final class OrientationLock: NSObject, UIApplicationDelegate {
    private(set) var mask = UIInterfaceOrientationMask.portrait

    override public init() {
        super.init()
    }

    public func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        mask
    }

    /// Answers with `orientation`'s mask from now on.
    func follow(_ orientation: ScreenOrientation) {
        mask = interfaceMask(orientation)
    }
}

/// The window's mask for an orientation.
func interfaceMask(_ orientation: ScreenOrientation) -> UIInterfaceOrientationMask {
    switch orientation {
    case .portrait: .portrait
    case .landscape: .landscape
    case .any: .all
    }
}

/// The device as Dish lays out for it: an iPad, or an iPhone for every
/// other idiom UIKit names, none of which Dish runs on.
func deviceIdiom(_ idiom: UIUserInterfaceIdiom) -> DeviceIdiom {
    switch idiom {
    case .pad: .pad
    case .phone, .unspecified, .tv, .carPlay, .mac, .vision: .phone
    @unknown default: .phone
    }
}
