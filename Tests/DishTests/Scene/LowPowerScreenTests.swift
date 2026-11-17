// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import Dish

/// The dim's brightness move: the floor once on the way down, keeping what
/// the screen had; that value once on the way up; nothing in between.
final class LowPowerScreenTests: XCTestCase {

    func testDimmingKeepsTheBrightnessFoundAndSetsTheFloorOnce() {
        XCTAssertEqual(brightnessMove(dimmed: true, kept: nil, current: 0.8), BrightnessMove(set: 0.01, keep: 0.8))
        XCTAssertEqual(brightnessMove(dimmed: true, kept: 0.8, current: 0.01), BrightnessMove(set: nil, keep: 0.8), "dimmed already")
    }

    func testWakingGivesBackWhatWasKeptOnce() {
        XCTAssertEqual(brightnessMove(dimmed: false, kept: 0.8, current: 0.01), BrightnessMove(set: 0.8, keep: nil))
        XCTAssertEqual(brightnessMove(dimmed: false, kept: nil, current: 0.8), BrightnessMove(set: nil, keep: nil), "nothing to give back")
    }

    func testTheFloorIsAndroids() {
        XCTAssertEqual(dimmedBrightness, 0.01)
    }
}
