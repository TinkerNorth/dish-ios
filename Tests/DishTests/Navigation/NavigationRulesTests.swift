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
        XCTAssertTrue(playCoverMoves(from: .dim, to: .play(.gamepad)))
        XCTAssertFalse(playCoverMoves(from: .play(.gamepad), to: .play(.mouse)), "the pause menu moving between screens")
        XCTAssertFalse(playCoverMoves(from: nil, to: .dim))
        XCTAssertFalse(playCoverMoves(from: nil, to: .setup(.guide)))
        XCTAssertFalse(playCoverMoves(from: .setup(.firstRun), to: nil))
    }

    /// The low-power dim may rise only over the bare tabs: never under a
    /// cover, nor over a sheet, whose pairing the dim would cancel.
    func testTheDimMayRiseOnlyOverTheBareTabs() {
        XCTAssertTrue(dimAllowed(NavigationState()))
        XCTAssertTrue(dimAllowed(after(.select(.settings), .push(.help))))
        XCTAssertFalse(dimAllowed(after(.openSheet(.addByAddress))))
        XCTAssertFalse(dimAllowed(after(.openSetup(.guide))))
        XCTAssertFalse(dimAllowed(after(.openPlay(.gamepad))))
        XCTAssertFalse(dimAllowed(after(.dim)))
    }
}
