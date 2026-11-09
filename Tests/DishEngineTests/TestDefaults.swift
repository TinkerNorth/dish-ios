// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest

/// A `UserDefaults` suite of its own for one test, emptied when the test ends.
enum TestDefaults {
    static func fresh(_ test: XCTestCase) throws -> UserDefaults {
        let suite = "com.tinkernorth.dish.ios.tests.\(UUID().uuidString)"
        test.addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }
}
