// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The three tips the App Store sells, smallest first. Each is a consumable
/// in-app purchase that unlocks nothing.
package enum TipTier: String, CaseIterable {
    case small
    case medium
    case large

    private static let productPrefix = "com.tinkernorth.dish.ios.tip."

    /// The identifier App Store Connect and `App/Dish.storekit` sell it under.
    package var productID: String {
        Self.productPrefix + rawValue
    }

    package init?(productID: String) {
        guard productID.hasPrefix(Self.productPrefix) else { return nil }
        self.init(rawValue: String(productID.dropFirst(Self.productPrefix.count)))
    }
}

/// A tip as the App Store offers it. The price is StoreKit's own string,
/// already in the person's currency and locale, and passes through unchanged.
package struct TipProduct: Equatable {
    package let tier: TipTier
    package let displayPrice: String

    package init(tier: TipTier, displayPrice: String) {
        self.tier = tier
        self.displayPrice = displayPrice
    }
}

/// How a purchase the App Store answered ended.
package enum TipPurchase: Equatable {
    case completed
    case cancelled
    /// Waiting on someone else, such as Ask to Buy.
    case pending
}

package enum TipStoreError: Error, Equatable {
    /// The App Store does not sell the tier, or never listed it.
    case unavailable
    /// The App Store's receipt for the purchase did not verify.
    case unverified
    case failed
}

/// The seam to the App Store: what it sells, a tip, and Restore.
@MainActor
package protocol TipStore: AnyObject {
    func products() async throws -> [TipProduct]
    func purchase(_ tier: TipTier) async throws -> TipPurchase
    /// Finishes every tip the App Store still holds unfinished; whether
    /// there was one.
    func restore() async throws -> Bool
}
