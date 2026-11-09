// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Observation
import XCTest
@testable import DishKernel

/// Counts the changes Observation reports for a tracked read.
@MainActor
private final class ChangeCount {
    private(set) var changes = 0

    func record() {
        changes += 1
    }
}

@MainActor
final class StateSourceTests: XCTestCase {

    private func observing(_ source: StateSource<some Any>) -> ChangeCount {
        let count = ChangeCount()
        withObservationTracking {
            _ = source.state
        } onChange: {
            MainActor.assumeIsolated(count.record)
        }
        return count
    }

    func testTheInitialValueIsTheOneGiven() {
        XCTAssertEqual(StateSource(initial: 7).state, 7)
    }

    func testADifferentValueIsPublished() {
        let source = StateSource(initial: 1)
        let count = observing(source)
        source.setState(2)
        XCTAssertEqual(source.state, 2)
        XCTAssertEqual(count.changes, 1)
    }

    func testAnEqualValueIsNotPublished() {
        let source = StateSource(initial: 1)
        let count = observing(source)
        source.setState(1)
        XCTAssertEqual(source.state, 1)
        XCTAssertEqual(count.changes, 0)
    }

    func testUpdateStateAppliesTheReducerUnderTheSameRule() {
        let source = StateSource(initial: 10)
        let unchanged = observing(source)
        source.updateState { $0 + 0 }
        XCTAssertEqual(unchanged.changes, 0)
        let changed = observing(source)
        source.updateState { $0 * 2 }
        XCTAssertEqual(source.state, 20)
        XCTAssertEqual(changed.changes, 1)
    }
}
