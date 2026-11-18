// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// When Dish holds the screen on: a session streaming with an active
/// binding and Keep screen on set, and at no other time, so the phone locks
/// like any other app otherwise.
final class ScreenHoldTests: XCTestCase {

    private func session(_ phase: SessionPhase, pads: Int = 1, active: Int? = nil) -> SessionFact {
        SessionFact(pcName: "Living Room PC", pads: pads, active: active, latencyMs: 4, phase: phase)
    }

    func testAStreamingSessionWithAnActiveBindingHoldsTheScreen() {
        XCTAssertTrue(screenHeld(session: session(.streaming), keepScreenOn: true))
        XCTAssertTrue(screenHeld(session: session(.streaming, pads: 3, active: 1), keepScreenOn: true), "one present pad is enough")
    }

    func testABindingWhosePadIsAwayHoldsNothing() {
        XCTAssertFalse(screenHeld(session: session(.streaming, pads: 2, active: 0), keepScreenOn: true))
        XCTAssertFalse(screenHeld(session: session(.streaming, pads: 0), keepScreenOn: true), "a bare connection")
    }

    func testAnythingButStreamingLetsThePhoneLock() {
        XCTAssertFalse(screenHeld(session: session(.stoppedResponding), keepScreenOn: true), "Reconnect waits for the person")
        XCTAssertFalse(screenHeld(session: session(.reconnecting), keepScreenOn: true))
        XCTAssertFalse(screenHeld(session: session(.failed(.dataPathBlocked)), keepScreenOn: true))
        XCTAssertFalse(screenHeld(session: nil, keepScreenOn: true))
    }

    func testKeepScreenOnOffLetsThePhoneLockWhateverStreams() {
        XCTAssertFalse(screenHeld(session: session(.streaming), keepScreenOn: false))
    }

    func testActiveIsEveryBoundPadUnlessSaidOtherwise() {
        XCTAssertEqual(session(.streaming, pads: 3).active, 3)
        XCTAssertEqual(session(.streaming, pads: 3, active: 1).active, 1)
    }
}
