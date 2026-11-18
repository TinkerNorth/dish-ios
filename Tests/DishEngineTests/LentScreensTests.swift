// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// The screens the phone can lend a pad: only a pad with no touchpad of its
/// own, on a session that is up; the touchpad when the type renders one,
/// the mouse when the host grants it.
final class LentScreensTests: XCTestCase {

    func testAPadWithNoTouchpadOnALiveSessionGetsWhatTheTypeAndTheHostAllow() {
        XCTAssertEqual(
            lentScreens(padHasTouchpad: false, sessionUp: true, typeOffersDs4: true, hostMouseControl: true),
            [.touchpad, .mouse]
        )
        XCTAssertEqual(lentScreens(padHasTouchpad: false, sessionUp: true, typeOffersDs4: false, hostMouseControl: true), [.mouse])
        XCTAssertEqual(lentScreens(padHasTouchpad: false, sessionUp: true, typeOffersDs4: true, hostMouseControl: false), [.touchpad])
        XCTAssertEqual(lentScreens(padHasTouchpad: false, sessionUp: true, typeOffersDs4: false, hostMouseControl: false), [])
    }

    func testAPadWithATouchpadOfItsOwnStreamsThatInstead() {
        XCTAssertEqual(lentScreens(padHasTouchpad: true, sessionUp: true, typeOffersDs4: true, hostMouseControl: true), [])
    }

    func testASessionThatIsDownLendsNothing() {
        XCTAssertEqual(lentScreens(padHasTouchpad: false, sessionUp: false, typeOffersDs4: true, hostMouseControl: true), [])
    }

    /// The on-screen controller's touchpad is on its gamepad, so besides the
    /// gamepad it opens the mouse alone, once the host grants it.
    func testTheOnScreenControllerOpensTheMouseOnceTheHostGrantsIt() {
        XCTAssertEqual(onScreenSurfaces(sessionUp: true, hostMouseControl: true), [.mouse])
        XCTAssertEqual(onScreenSurfaces(sessionUp: true, hostMouseControl: false), [])
        XCTAssertEqual(onScreenSurfaces(sessionUp: false, hostMouseControl: true), [])
    }
}
