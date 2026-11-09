// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// Support Dish: the shelf the App Store sells, a tip and its outcomes, and
/// Restore, through the recorded store.
@MainActor
final class AppModelSupportTests: XCTestCase {

    private static let shelf = [
        TipProduct(tier: .large, displayPrice: "$9.99"),
        TipProduct(tier: .small, displayPrice: "$0.99"),
        TipProduct(tier: .medium, displayPrice: "$4.99")
    ]

    private static let smallestFirst = [
        TipProduct(tier: .small, displayPrice: "$0.99"),
        TipProduct(tier: .medium, displayPrice: "$4.99"),
        TipProduct(tier: .large, displayPrice: "$9.99")
    ]

    private func model(_ tips: RecordedTipStore) throws -> AppModel {
        try AppModel(defaults: TestDefaults.fresh(self), tips: tips, controllerSource: FakeControllerSource())
    }

    private func loaded(_ tips: RecordedTipStore) async throws -> AppModel {
        let model = try model(tips)
        await model.loadTips().value
        return model
    }

    func testTheShelfIsLoadingUntilTheStoreAnswers() throws {
        let model = try model(RecordedTipStore(shelf: .success(Self.shelf)))
        XCTAssertEqual(model.shellFacts.support, SupportFacts(shelf: .loading, moment: .idle))
    }

    func testLoadingPutsTheTipsOnTheShelfSmallestFirstWithTheStoresOwnPrices() async throws {
        let tips = RecordedTipStore(shelf: .success(Self.shelf))
        let model = try await loaded(tips)
        XCTAssertEqual(model.shellFacts.support.shelf, .ready(Self.smallestFirst))
        XCTAssertEqual(tips.loads, 1)
    }

    func testAStoreThatFailsOrSellsNothingLeavesTheShelfUnavailable() async throws {
        let failing = try await loaded(RecordedTipStore(shelf: .failure(.unavailable)))
        XCTAssertEqual(failing.shellFacts.support.shelf, .unavailable)
        let empty = try await loaded(RecordedTipStore(shelf: .success([])))
        XCTAssertEqual(empty.shellFacts.support.shelf, .unavailable)
    }

    func testTheSupportPageAppearingLoadsTheShelf() async throws {
        let tips = RecordedTipStore(shelf: .success(Self.shelf))
        let model = try model(tips)
        await model.pageAppeared(.support)?.value
        XCTAssertEqual(tips.loads, 1)
        XCTAssertEqual(model.shellFacts.support.shelf, .ready(Self.smallestFirst))
    }

    func testACompletedTipSaysThankYou() async throws {
        let tips = RecordedTipStore(shelf: .success(Self.shelf), purchase: .success(.completed))
        let model = try await loaded(tips)
        await model.tip(.medium).value
        XCTAssertEqual(tips.purchases, [.medium])
        XCTAssertEqual(model.shellFacts.support.moment, .thanked)
    }

    func testACancelledTipLeavesThePageAsItWas() async throws {
        let model = try await loaded(RecordedTipStore(shelf: .success(Self.shelf), purchase: .success(.cancelled)))
        await model.tip(.small).value
        XCTAssertEqual(model.shellFacts.support.moment, .idle)
    }

    func testATipWaitingForApprovalIsPending() async throws {
        let model = try await loaded(RecordedTipStore(shelf: .success(Self.shelf), purchase: .success(.pending)))
        await model.tip(.large).value
        XCTAssertEqual(model.shellFacts.support.moment, .pending)
    }

    func testATipTheStoreRefusesIsAFailure() async throws {
        let model = try await loaded(RecordedTipStore(shelf: .success(Self.shelf), purchase: .failure(.failed)))
        await model.tip(.small).value
        XCTAssertEqual(model.shellFacts.support.moment, .failed)
    }

    func testATipIsBuyingWhileTheStoreIsAsked() async throws {
        let model = try await loaded(RecordedTipStore(shelf: .success(Self.shelf)))
        let task = model.tip(.medium)
        XCTAssertEqual(model.shellFacts.support.moment, .buying(.medium))
        await task.value
    }

    func testASecondTipWhileOneIsBuyingIsIgnored() async throws {
        let tips = RecordedTipStore(shelf: .success(Self.shelf), purchase: .success(.completed))
        let model = try await loaded(tips)
        let first = model.tip(.small)
        let second = model.tip(.large)
        await first.value
        await second.value
        XCTAssertEqual(tips.purchases, [.small])
    }

    func testRestoringAnUnfinishedTipSaysThankYou() async throws {
        let tips = RecordedTipStore(shelf: .success(Self.shelf), restore: .success(true))
        let model = try await loaded(tips)
        let task = model.restoreTips()
        XCTAssertEqual(model.shellFacts.support.moment, .restoring)
        await task.value
        XCTAssertEqual(tips.restores, 1)
        XCTAssertEqual(model.shellFacts.support.moment, .thanked)
    }

    func testRestoringWithNothingToFinishSaysSo() async throws {
        let model = try await loaded(RecordedTipStore(shelf: .success(Self.shelf), restore: .success(false)))
        await model.restoreTips().value
        XCTAssertEqual(model.shellFacts.support.moment, .nothingToRestore)
    }

    func testARestoreTheStoreRefusesIsAFailure() async throws {
        let model = try await loaded(RecordedTipStore(shelf: .success(Self.shelf), restore: .failure(.failed)))
        await model.restoreTips().value
        XCTAssertEqual(model.shellFacts.support.moment, .failed)
    }
}
