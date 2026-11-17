// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI
import XCTest
@testable import Dish

/// What a control does under the finger: the wash while pressed, the shrink
/// of one that stands on its own, the quick way in and the slower way out,
/// the fade when disabled.
final class ButtonStylesTests: XCTestCase {

    func testAStatesLayerShowsWholeOrNotAtAll() {
        XCTAssertEqual(layerOpacity(shown: true), 1)
        XCTAssertEqual(layerOpacity(shown: false), 0)
    }

    func testAControlShrinksUnderTheFingerAndComesBack() {
        XCTAssertEqual(pressedScale(pressed: true), DishMotion.pressScale)
        XCTAssertEqual(pressedScale(pressed: false), 1)
        XCTAssertLessThan(DishMotion.pressScale, 1, "a shrink, not a swell")
    }

    func testThePressComesQuicklyAndGoesSlowlyEnoughToShow() {
        XCTAssertEqual(pressAnimation(pressed: true), DishMotion.pressIn)
        XCTAssertEqual(pressAnimation(pressed: false), DishMotion.pressOut)
        XCTAssertNotEqual(DishMotion.pressIn, DishMotion.pressOut, "a tap is too short to show unless the way out is longer")
    }

    func testADisabledControlFades() {
        XCTAssertEqual(controlOpacity(enabled: false), DishOpacity.disabled)
        XCTAssertEqual(controlOpacity(enabled: true), 1)
    }
}
