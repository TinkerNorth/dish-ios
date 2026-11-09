// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

@MainActor
final class RecordedLocalNetworkAccessTests: XCTestCase {

    func testAFreshAccessHasNotBeenAskedAndKnowsNothing() {
        let access = RecordedLocalNetworkAccess()
        XCTAssertEqual(access.status, .unknown)
        XCTAssertEqual(access.asks, 0)
        XCTAssertEqual(access.scans, 0)
    }

    func testAskingIsCountedAndLeavesTheStatusUnknownUntilDiscoveryAnswers() {
        let access = RecordedLocalNetworkAccess()
        access.ask()
        access.ask()
        XCTAssertEqual(access.asks, 2)
        XCTAssertEqual(access.status, .unknown)
    }

    func testScanningIsCounted() {
        let access = RecordedLocalNetworkAccess()
        access.scan()
        XCTAssertEqual(access.scans, 1)
        XCTAssertEqual(access.asks, 0)
    }
}
