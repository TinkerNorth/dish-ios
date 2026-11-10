// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The device the app runs on, as the scene reads it once.
enum DeviceIdiom: Equatable {
    case phone
    case pad
}

/// Which way the app may turn. The scene turns the window to it.
enum ScreenOrientation: Equatable {
    case portrait
    case landscape
    /// Any of the four: whichever way the device is held.
    case any
}

/// An iPhone stands upright and lies on its side for play. An iPad follows
/// the device on every screen, play included: iPadOS turns the window of an
/// app that shares the screen with the device, whatever the app's mask
/// says, and refuses it a turn of its own.
func screenOrientation(for cover: Cover?, idiom: DeviceIdiom) -> ScreenOrientation {
    switch idiom {
    case .phone: phoneOrientation(for: cover)
    case .pad: .any
    }
}

/// The play screens are landscape, every other screen portrait.
private func phoneOrientation(for cover: Cover?) -> ScreenOrientation {
    switch cover {
    case .play: .landscape
    case .setup, .dim, nil: .portrait
    }
}
