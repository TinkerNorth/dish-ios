// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import StoreKit

/// The App Store through StoreKit 2. A tip is a consumable: it is finished
/// as soon as it verifies, since it unlocks nothing to keep.
@MainActor
package final class StoreKitTipStore: TipStore {
    /// The products the last listing found, by tier, so a purchase buys the
    /// one whose price the page showed.
    private var listed: [TipTier: Product] = [:]
    /// Finishes a tip that completes away from the page (Ask to Buy, a
    /// purchase interrupted by a crash); started with the first listing.
    private var updates: Task<Void, Never>?

    package init() {}

    package func products() async throws -> [TipProduct] {
        listenForUpdates()
        let found = try await Product.products(for: TipTier.allCases.map(\.productID))
        listed = Dictionary(found.compactMap(tiered), uniquingKeysWith: keepFirst)
        return TipTier.allCases.compactMap(tipProduct)
    }

    package func purchase(_ tier: TipTier) async throws -> TipPurchase {
        guard let product = listed[tier] else { throw TipStoreError.unavailable }
        let result = try await product.purchase()
        switch result {
        case let .success(verification):
            try await Self.finish(verification)
            return .completed
        case .userCancelled: return .cancelled
        case .pending: return .pending
        @unknown default: return .cancelled
        }
    }

    package func restore() async throws -> Bool {
        try await AppStore.sync()
        var found = false
        for await unfinished in Transaction.unfinished {
            try await Self.finish(unfinished)
            found = true
        }
        return found
    }

    private func tipProduct(_ tier: TipTier) -> TipProduct? {
        listed[tier].map { TipProduct(tier: tier, displayPrice: $0.displayPrice) }
    }

    private func listenForUpdates() {
        guard updates == nil else { return }
        updates = Task.detached(priority: .background) { await Self.finishUpdates() }
    }

    private nonisolated static func finishUpdates() async {
        for await update in Transaction.updates {
            try? await finish(update)
        }
    }

    /// A verified tip is finished; an unverified one is left to the App Store.
    private nonisolated static func finish(_ verification: VerificationResult<Transaction>) async throws {
        switch verification {
        case let .verified(transaction): await transaction.finish()
        case .unverified: throw TipStoreError.unverified
        }
    }
}

private func tiered(_ product: Product) -> (TipTier, Product)? {
    TipTier(productID: product.id).map { ($0, product) }
}

private func keepFirst(_ first: Product, _: Product) -> Product {
    first
}
