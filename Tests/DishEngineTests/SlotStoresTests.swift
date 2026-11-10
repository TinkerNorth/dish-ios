// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Observation
import XCTest
@testable import DishEngine

/// The per-binding stores the controller page reads: the satellite's motion
/// word per (satellite, pad), set by an apply and cleared with the binding.
@MainActor
final class SlotStoresTests: XCTestCase {

    private let desk = SlotKey(connectionId: "desk", slotId: "pad")
    private let den = SlotKey(connectionId: "den", slotId: "pad")

    func testAMotionWordIsReadBackAndClearedPerBinding() {
        let store = MotionBackendStatusStore()
        let good = MotionBackendStatus(sinkSupportedForType: true, backendOk: true)
        let noSink = MotionBackendStatus(sinkSupportedForType: false, backendOk: true)
        store.setStatus(good, for: desk)
        store.setStatus(noSink, for: den)
        XCTAssertEqual(store.statusFor(desk), good)
        XCTAssertEqual(store.statusFor(den), noSink)
        XCTAssertTrue(good.effective)
        XCTAssertFalse(noSink.effective)
        store.clear(desk)
        XCTAssertNil(store.statusFor(desk))
        store.clearConnection("den")
        XCTAssertEqual(store.state, [:])
    }

    func testTheSameWordTwiceIsOneChange() {
        let store = MotionBackendStatusStore()
        let good = MotionBackendStatus(sinkSupportedForType: true, backendOk: true)
        let counter = ChangeCounter()
        counter.watch(store)
        store.setStatus(good, for: desk)
        XCTAssertEqual(counter.changes, 1)
        counter.watch(store)
        store.setStatus(good, for: desk)
        XCTAssertEqual(counter.changes, 1, "a word that did not change is not a change")
    }
}

/// Counts the changes Observation reports of a store's state, one per arming.
@MainActor
private final class ChangeCounter {
    private(set) var changes = 0

    func watch(_ store: MotionBackendStatusStore) {
        withObservationTracking {
            _ = store.state
        } onChange: { [weak self] in
            MainActor.assumeIsolated { self?.changes += 1 }
        }
    }
}
