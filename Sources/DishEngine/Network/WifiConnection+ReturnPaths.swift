// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The return paths, rumble, the light bar, the adaptive triggers and the
/// player LEDs: the router hands the connection its routes, the connection
/// keeps them so a reconnect's fresh client is wired the same way, and the
/// client's receive loop gates each command against them and posts it to
/// the pad's feedback in one hop. The audio frames have no route: iOS gives
/// apps no pad speaker, so the receive loop recognises and skips them.
extension WifiConnection {

    package func setFeedbackRoutes(_ routes: FeedbackRoutes) {
        feedbackRoutes = routes
        client?.setFeedbackRoutes(routes)
    }

    var hasFeedbackRoutes: Bool {
        feedbackRoutes != nil
    }
}
