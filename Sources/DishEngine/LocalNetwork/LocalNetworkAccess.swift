// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The seam to iOS's Local Network permission and to discovery: what iOS
/// has answered, a way to make it put its question, and a way to look for
/// PCs on the Wi‑Fi.
@MainActor
package protocol LocalNetworkAccess: AnyObject {
    var status: LocalNetworkStatus { get }
    func ask()
    func scan()
}

/// The one access until discovery lands: it counts what it was asked for and
/// knows nothing, so the status stays unknown.
@MainActor
package final class RecordedLocalNetworkAccess: LocalNetworkAccess {
    package let status = LocalNetworkStatus.unknown
    package private(set) var asks = 0
    package private(set) var scans = 0

    package init() {}

    package func ask() {
        asks += 1
    }

    package func scan() {
        scans += 1
    }
}
