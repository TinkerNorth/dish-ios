// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Which way the app may turn: the play screens are landscape only, every
/// other screen portrait only. The scene turns the window to it.
enum ScreenOrientation: Equatable {
    case portrait
    case landscape
}

func screenOrientation(for cover: Cover?) -> ScreenOrientation {
    switch cover {
    case .play: .landscape
    case .setup, .dim, nil: .portrait
    }
}
