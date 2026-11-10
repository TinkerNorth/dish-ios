// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// A page that needs something running only while it is on screen.
package enum ShownPage: Equatable {
    /// Words an offline PC's last sighting, so it runs the clock.
    case connections
    /// Asks the App Store what it sells each time it opens.
    case support
    /// The low-power dim words the time.
    case dim
    /// Diagnostics re-reads the sessions' words, the pads' rates and the
    /// lock statistics once a second while it shows.
    case diagnostics
}

/// The pages' lifecycle intents.
package extension AppModel {
    /// The task a page started, when it asked for one, so a test can wait
    /// for it.
    @discardableResult
    func pageAppeared(_ page: ShownPage) -> Task<Void, Never>? {
        switch page {
        case .connections, .dim:
            clock.start()
            return nil
        case .support:
            return loadTips()
        case .diagnostics:
            diagnostics.start()
            return nil
        }
    }

    func pageDisappeared(_ page: ShownPage) {
        switch page {
        case .connections, .dim: clock.stop()
        case .support: break
        case .diagnostics: diagnostics.stop()
        }
    }
}
