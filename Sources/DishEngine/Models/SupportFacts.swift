// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// What the App Store sells right now.
package enum TipShelf: Equatable {
    /// Asked and not yet answered, or never asked.
    case loading
    /// Smallest first, with the App Store's own prices.
    case ready([TipProduct])
    /// The App Store failed or sells no tip.
    case unavailable
}

/// Where the last tip or Restore stands.
package enum TipMoment: Equatable {
    case idle
    case buying(TipTier)
    case restoring
    case thanked
    /// Waiting on approval, such as Ask to Buy.
    case pending
    case failed
    case nothingToRestore
}

/// Support Dish: the shelf and the moment.
package struct SupportFacts: Equatable {
    package let shelf: TipShelf
    package let moment: TipMoment

    package init(shelf: TipShelf, moment: TipMoment) {
        self.shelf = shelf
        self.moment = moment
    }

    /// Before the page first asks the App Store.
    package static let initial = SupportFacts(shelf: .loading, moment: .idle)

    /// Whether a tip or a Restore is waiting on the App Store.
    package var busy: Bool {
        switch moment {
        case .buying, .restoring: true
        case .idle, .thanked, .pending, .failed, .nothingToRestore: false
        }
    }

    package func with(shelf: TipShelf) -> SupportFacts {
        SupportFacts(shelf: shelf, moment: moment)
    }

    package func with(moment: TipMoment) -> SupportFacts {
        SupportFacts(shelf: shelf, moment: moment)
    }
}
