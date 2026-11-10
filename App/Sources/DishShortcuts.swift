// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import AppIntents
import Dish

/// The App Shortcuts Siri, Spotlight and the Shortcuts app offer for Dish:
/// the three play screens, the dim and Connect to a PC. App Intents reads a
/// provider only from the app's own target, and every word here from the
/// app bundle's catalogs in `App/Resources`; the intents are the Dish
/// package's, merged into the app's metadata at build time.
struct DishShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenGamepadIntent(),
            phrases: ["Open the gamepad in \(.applicationName)"],
            shortTitle: "Open the gamepad",
            systemImageName: "gamecontroller"
        )
        AppShortcut(
            intent: OpenTouchpadIntent(),
            phrases: ["Open the touchpad in \(.applicationName)"],
            shortTitle: "Open the touchpad",
            systemImageName: "rectangle.and.hand.point.up.left"
        )
        AppShortcut(
            intent: OpenMouseIntent(),
            phrases: ["Open the mouse in \(.applicationName)"],
            shortTitle: "Open the mouse",
            systemImageName: "cursorarrow"
        )
        AppShortcut(
            intent: DimScreenIntent(),
            phrases: ["Dim the screen in \(.applicationName)"],
            shortTitle: "Dim the screen",
            systemImageName: "moon.fill"
        )
        AppShortcut(
            intent: ConnectToPCIntent(),
            phrases: ["Connect \(.applicationName) to a PC"],
            shortTitle: "Connect to a PC",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
    }
}
