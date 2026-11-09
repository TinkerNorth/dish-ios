// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// The three tips the App Store sells, and the recorded store the tests and
/// previews use in its place.
@MainActor
final class TipStoreTests: XCTestCase {

    func testTheProductIdentifiersAreTheAppStoresSmallestFirst() {
        XCTAssertEqual(TipTier.allCases.map(\.productID), [
            "com.tinkernorth.dish.ios.tip.small",
            "com.tinkernorth.dish.ios.tip.medium",
            "com.tinkernorth.dish.ios.tip.large"
        ])
    }

    func testAProductIdentifierNamesItsTier() {
        XCTAssertEqual(TipTier(productID: "com.tinkernorth.dish.ios.tip.medium"), .medium)
        XCTAssertNil(TipTier(productID: "com.tinkernorth.dish.ios.tip.huge"))
    }

    func testTheRecordedStoreCountsWhatItWasAskedAndAnswersAsTold() async throws {
        let shelf = [TipProduct(tier: .small, displayPrice: "0,99 €")]
        let tips = RecordedTipStore(shelf: .success(shelf), purchase: .success(.pending), restore: .success(true))
        let products = try await tips.products()
        let outcome = try await tips.purchase(.small)
        let restored = try await tips.restore()
        XCTAssertEqual(products, shelf)
        XCTAssertEqual(outcome, .pending)
        XCTAssertTrue(restored)
        XCTAssertEqual(tips.loads, 1)
        XCTAssertEqual(tips.purchases, [.small])
        XCTAssertEqual(tips.restores, 1)
    }

    func testTheRecordedStoreThrowsTheFailureItWasGiven() async {
        let tips = RecordedTipStore(shelf: .failure(.unavailable), purchase: .failure(.unverified), restore: .failure(.failed))
        await assertThrows(TipStoreError.unavailable) { _ = try await tips.products() }
        await assertThrows(TipStoreError.unverified) { _ = try await tips.purchase(.large) }
        await assertThrows(TipStoreError.failed) { _ = try await tips.restore() }
    }

    private func assertThrows(_ expected: TipStoreError, _ body: () async throws -> Void) async {
        do {
            try await body()
            XCTFail("expected \(expected)")
        } catch {
            XCTAssertEqual(error as? TipStoreError, expected)
        }
    }
}
