// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The App Store as the tests and previews have it: it answers as it was
/// told and counts what it was asked.
@MainActor
package final class RecordedTipStore: TipStore {
    private let shelf: Result<[TipProduct], TipStoreError>
    private let purchaseResult: Result<TipPurchase, TipStoreError>
    private let restoreResult: Result<Bool, TipStoreError>
    package private(set) var loads = 0
    package private(set) var purchases: [TipTier] = []
    package private(set) var restores = 0

    package init(
        shelf: Result<[TipProduct], TipStoreError>,
        purchase: Result<TipPurchase, TipStoreError> = .success(.completed),
        restore: Result<Bool, TipStoreError> = .success(false)
    ) {
        self.shelf = shelf
        purchaseResult = purchase
        restoreResult = restore
    }

    package func products() async throws -> [TipProduct] {
        loads += 1
        return try shelf.get()
    }

    package func purchase(_ tier: TipTier) async throws -> TipPurchase {
        purchases.append(tier)
        return try purchaseResult.get()
    }

    package func restore() async throws -> Bool {
        restores += 1
        return try restoreResult.get()
    }
}
