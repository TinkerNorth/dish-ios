// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import XCTest
@testable import Dish

/// Support Dish: the heart and the pitch, the tips with the App Store's own
/// prices, Restore, and every outcome.
final class SupportMappersTests: XCTestCase {

    private static let shelf = [
        TipProduct(tier: .small, displayPrice: "$0.99"),
        TipProduct(tier: .medium, displayPrice: "$4.99"),
        TipProduct(tier: .large, displayPrice: "$9.99")
    ]

    private func page(_ shelf: TipShelf = .ready(shelf), _ moment: TipMoment = .idle) -> SupportPageState {
        supportPageState(support: SupportFacts(shelf: shelf, moment: moment))
    }

    private func buttons(_ state: SupportPageState) throws -> [TipButtonState] {
        try XCTUnwrap(tipButtons(state.shelf), "the shelf shows its tips")
    }

    private func tipButtons(_ shelf: SupportShelfState) -> [TipButtonState]? {
        switch shelf {
        case let .tips(buttons): buttons
        case .loading, .unavailable: nil
        }
    }

    func testTheHeadOfThePage() {
        let state = page()
        XCTAssertEqual(state.title, "Support Dish")
        XCTAssertEqual(state.heartSymbol, "heart.fill")
        XCTAssertEqual(
            state.pitch,
            "Dish is free and open source. A tip pays for the time that goes into Dish and Satellite. Every feature stays free, tip or not."
        )
        XCTAssertEqual(state.tipsTitle, "Tips")
        XCTAssertEqual(state.footnote, "The App Store handles the payment. Dish never sees your card.")
    }

    func testWhileTheStoreIsAskedThePageSaysLoadingAndRestoreWaits() {
        let state = page(.loading)
        XCTAssertEqual(state.shelf, .loading("Loading"))
        XCTAssertFalse(state.restoreEnabled)
    }

    func testTheThreeTipsShowTheStoresPricesUnchanged() throws {
        let state = page()
        XCTAssertEqual(try buttons(state), [
            TipButtonState(tier: .small, title: "Small tip", price: "$0.99", busy: false, enabled: true),
            TipButtonState(tier: .medium, title: "Medium tip", price: "$4.99", busy: false, enabled: true),
            TipButtonState(tier: .large, title: "Large tip", price: "$9.99", busy: false, enabled: true)
        ])
        XCTAssertEqual(state.restoreTitle, "Restore purchases")
        XCTAssertTrue(state.restoreEnabled)
        XCTAssertEqual(state.notice, .none)
    }

    func testAForeignPriceIsShownAsTheStoreWroteIt() throws {
        let euro = page(.ready([TipProduct(tier: .small, displayPrice: "0,99 €")]))
        XCTAssertEqual(try buttons(euro).map(\.price), ["0,99 €"])
    }

    func testAStoreThatSellsNothingOffersToTryAgain() {
        XCTAssertEqual(page(.unavailable).shelf, .unavailable(message: "Tips aren’t available right now.", retry: "Try again"))
    }

    func testWhileATipIsBoughtItsButtonIsBusyAndNothingElseCanBeTapped() throws {
        let state = page(.ready(Self.shelf), .buying(.medium))
        XCTAssertEqual(try buttons(state).map(\.busy), [false, true, false])
        XCTAssertEqual(try buttons(state).map(\.enabled), [false, false, false])
        XCTAssertFalse(state.restoreEnabled)
    }

    func testWhileRestoringNothingCanBeTapped() throws {
        let state = page(.ready(Self.shelf), .restoring)
        XCTAssertEqual(try buttons(state).map(\.enabled), [false, false, false])
        XCTAssertFalse(state.restoreEnabled)
    }

    func testACompletedTipSaysThankYou() {
        XCTAssertEqual(
            page(.ready(Self.shelf), .thanked).notice,
            .thanks(title: "Thank you", body: "Your tip keeps Dish free for everyone.")
        )
    }

    func testEveryOtherOutcomeIsANote() {
        XCTAssertEqual(page(.ready(Self.shelf), .pending).notice, .note(text: "Your tip is waiting for approval.", color: DishTheme.muted))
        XCTAssertEqual(
            page(.ready(Self.shelf), .failed).notice,
            .note(text: "The App Store couldn’t complete the tip.", color: DishTheme.error)
        )
        XCTAssertEqual(
            page(.ready(Self.shelf), .nothingToRestore).notice,
            .note(text: "There’s no tip to restore.", color: DishTheme.muted)
        )
    }
}
