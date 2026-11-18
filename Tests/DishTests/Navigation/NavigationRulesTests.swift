// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import Dish

/// The rules beside the reducer: which moves turn the window, and when the
/// low-power dim may rise.
final class NavigationRulesTests: XCTestCase {

    private func after(_ events: NavigationEvent...) -> NavigationState {
        events.reduce(NavigationState()) { reduceNavigation($0, $1).state }
    }

    /// Only a play cover rising or falling moves the window; those are the
    /// moves the store leaves unanimated.
    func testOnlyAPlayCoverRisingOrFallingMovesTheWindow() {
        XCTAssertTrue(playCoverMoves(from: nil, to: .play(.gamepad)))
        XCTAssertTrue(playCoverMoves(from: .play(.mouse), to: nil))
        XCTAssertTrue(playCoverMoves(from: .setup(.guide), to: .play(.gamepad)))
        XCTAssertFalse(playCoverMoves(from: .play(.gamepad), to: .play(.mouse)), "one play screen replacing another")
        XCTAssertFalse(playCoverMoves(from: nil, to: .setup(.guide)))
        XCTAssertFalse(playCoverMoves(from: .setup(.firstRun), to: nil))
    }

    /// The low-power countdown may run on any screen, the play screens and
    /// the sheets included, and rests only while the dim is up.
    func testTheCountdownMayRunAnywhereButUnderTheDim() {
        XCTAssertTrue(dimAllowed(NavigationState()))
        XCTAssertTrue(dimAllowed(after(.select(.settings), .push(.help))))
        XCTAssertTrue(dimAllowed(after(.openSheet(.addByAddress))))
        XCTAssertTrue(dimAllowed(after(.openSetup(.guide))))
        XCTAssertTrue(dimAllowed(after(.openPlay(.gamepad))))
        XCTAssertFalse(dimAllowed(after(.dim)))
        XCTAssertTrue(dimAllowed(after(.dim, .wake)))
    }
}
