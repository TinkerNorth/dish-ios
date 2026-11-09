// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import Dish

/// The pages Dish links to, and the ones it must not: tips go through the
/// App Store, so no donation site is linked.
final class DishLinksTests: XCTestCase {

    private let links = [DishLinks.website, DishLinks.source, DishLinks.privacy, DishLinks.satellite]

    func testEveryLinkIsTheFleetsOwnPage() {
        XCTAssertEqual(DishLinks.website?.absoluteString, "https://dish.tinkernorth.com")
        XCTAssertEqual(DishLinks.source?.absoluteString, "https://github.com/TinkerNorth/dish-ios")
        XCTAssertEqual(DishLinks.privacy?.absoluteString, "https://github.com/TinkerNorth/dish-ios/blob/main/PRIVACY.md")
        XCTAssertEqual(DishLinks.satellite?.absoluteString, "https://dish.tinkernorth.com/downloads/satellite")
    }

    func testEveryLinkIsHTTPS() {
        XCTAssertEqual(links.compactMap { $0?.scheme }, ["https", "https", "https", "https"])
    }

    func testNoLinkLeadsToADonationSite() {
        let hosts = links.compactMap { $0?.host() }
        for donation in ["ko-fi.com", "buymeacoffee.com"] {
            XCTAssertFalse(hosts.contains(donation), "Apple requires in-app purchase for tips")
        }
        XCTAssertFalse(links.contains { $0?.path().hasPrefix("/sponsors") == true })
    }
}
