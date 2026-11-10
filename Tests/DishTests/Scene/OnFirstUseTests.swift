// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import Dish

/// SwiftUI builds a scene again on its own and keeps the first build's state,
/// so what the scene owns is made on first use: a build SwiftUI throws away
/// makes nothing, and the kept one makes its value once.
@MainActor
final class OnFirstUseTests: XCTestCase {

    func testNothingIsMadeUntilTheValueIsRead() {
        var made = 0
        _ = OnFirstUse { made += 1 }
        _ = OnFirstUse { made += 1 }
        XCTAssertEqual(made, 0, "a holder SwiftUI throws away never makes its value")
    }

    func testTheValueIsMadeOnceAndReadBackTheSame() {
        var made = 0
        let holder = OnFirstUse { () -> NSObject in
            made += 1
            return NSObject()
        }
        let first = holder.value
        let second = holder.value
        XCTAssertEqual(made, 1)
        XCTAssertTrue(first === second, "every read sees the one value")
    }
}
