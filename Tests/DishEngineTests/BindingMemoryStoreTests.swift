// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// The satellite bindings kept across restarts, under `wifi_binding_list`:
/// one record per pad naming the satellite, rewritten on every bind, dropped
/// on unbind and with its satellite on Forget. The pad's pick lives with the
/// pad, under `emulated_type_preferences`. A value that does not read is
/// nothing stored.
@MainActor
final class BindingMemoryStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        defaults = try TestDefaults.fresh(self)
    }

    private var store: BindingMemoryStore {
        BindingMemoryStore(defaults: defaults)
    }

    private let den = RememberedSatelliteBinding(slotId: "pad", satelliteId: "mid:den")
    private let loft = RememberedSatelliteBinding(slotId: "other", satelliteId: "mid:loft")

    func testAFreshInstallRemembersNoBinding() {
        XCTAssertEqual(store.bindings(), [])
    }

    func testABindingRoundTripsThroughTheFleetsKey() {
        store.remember(den)
        store.remember(loft)
        XCTAssertNotNil(defaults.data(forKey: "wifi_binding_list"))
        XCTAssertEqual(store.bindings(), [den, loft], "a new store over the same defaults reads both back")
    }

    func testRememberingAPadAgainReplacesItsRecord() {
        store.remember(den)
        let moved = RememberedSatelliteBinding(slotId: "pad", satelliteId: "mid:loft")
        store.remember(moved)
        XCTAssertEqual(store.bindings(), [moved])
    }

    func testForgettingAPadDropsOnlyItsRecord() {
        store.remember(den)
        store.remember(loft)
        store.forget(slotId: "pad")
        XCTAssertEqual(store.bindings(), [loft])
    }

    func testForgettingASatelliteDropsEveryPadBoundToIt() {
        let second = RememberedSatelliteBinding(slotId: "third", satelliteId: "mid:den")
        store.remember(den)
        store.remember(loft)
        store.remember(second)
        store.forgetSatellite("mid:den")
        XCTAssertEqual(store.bindings(), [loft])
    }

    func testAValueThatDoesNotReadIsNothingStored() {
        defaults.set(Data("not json".utf8), forKey: "wifi_binding_list")
        XCTAssertEqual(store.bindings(), [])
    }
}
