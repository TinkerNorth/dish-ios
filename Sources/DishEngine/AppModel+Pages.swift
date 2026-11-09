// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// A page that needs something running only while it is on screen.
package enum ShownPage: Equatable {
    /// Words an offline PC's last sighting, so it runs the clock.
    case connections
}

/// The pages' lifecycle intents.
package extension AppModel {
    func pageAppeared(_ page: ShownPage) {
        switch page {
        case .connections: clock.start()
        }
    }

    func pageDisappeared(_ page: ShownPage) {
        switch page {
        case .connections: clock.stop()
        }
    }
}
