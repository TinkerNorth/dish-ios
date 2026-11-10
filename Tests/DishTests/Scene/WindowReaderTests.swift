// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI
import XCTest
@testable import Dish

/// What the scene reads of the window, the facts the pages lay out from:
/// SwiftUI's size class each way, and whether the window is on its side.
final class WindowReaderTests: XCTestCase {

    func testARegularSizeClassIsRegularAndAnyOtherCompact() {
        XCTAssertEqual(sizeClass(.regular), .regular)
        XCTAssertEqual(sizeClass(.compact), .compact)
        XCTAssertEqual(sizeClass(nil), .compact, "a class SwiftUI has not given yet is the phone's")
    }

    func testAWindowWiderThanTallIsOnItsSide() {
        XCTAssertEqual(windowShape(CGSize(width: 1210, height: 834)), .landscape)
        XCTAssertEqual(windowShape(CGSize(width: 834, height: 1210)), .portrait)
        XCTAssertEqual(windowShape(CGSize(width: 600, height: 600)), .portrait, "a square window is not on its side")
    }

    func testTheFactsCarryBothClassesAndTheShape() {
        let facts = windowFacts(width: .regular, height: .compact, shape: .landscape)
        XCTAssertEqual(facts, WindowFacts(width: .regular, height: .compact, shape: .landscape))
        let unknown = windowFacts(width: nil, height: nil, shape: .portrait)
        XCTAssertEqual(unknown, WindowFacts(width: .compact, height: .compact, shape: .portrait), "classes not given yet are compact")
    }

    func testBeforeTheSceneReadsTheWindowItIsAnUprightPhones() {
        XCTAssertEqual(WindowFacts.phone, WindowFacts(width: .compact, height: .regular, shape: .portrait))
    }
}
