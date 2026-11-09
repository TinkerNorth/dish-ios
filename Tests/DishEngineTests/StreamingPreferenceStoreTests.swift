// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

@MainActor
final class StreamingPreferenceStoreTests: XCTestCase {

    func testAFreshInstallKeepsTheScreenOnAndDimsAfterTwentySeconds() throws {
        let store = try StreamingPreferenceStore(defaults: TestDefaults.fresh(self))
        XCTAssertEqual(store.state, StreamingPreferences(keepScreenOn: true, dimAfter: .twentySeconds))
    }

    func testTheStoredValuesAreRead() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set(false, forKey: "keep_screen_on")
        defaults.set(120, forKey: "dim_after_seconds")
        XCTAssertEqual(StreamingPreferenceStore(defaults: defaults).state, StreamingPreferences(keepScreenOn: false, dimAfter: .twoMinutes))
    }

    func testNeverIsStoredAsZeroSeconds() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set(0, forKey: "dim_after_seconds")
        XCTAssertEqual(StreamingPreferenceStore(defaults: defaults).state.dimAfter, .never)
    }

    func testAnUnknownStoredDelayReadsAsTheDefault() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set(45, forKey: "dim_after_seconds")
        XCTAssertEqual(StreamingPreferenceStore(defaults: defaults).state.dimAfter, .twentySeconds)
        defaults.set("soon", forKey: "dim_after_seconds")
        XCTAssertEqual(StreamingPreferenceStore(defaults: defaults).state.dimAfter, .twentySeconds)
    }

    func testSettingEachValuePersistsAndPublishes() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = StreamingPreferenceStore(defaults: defaults)
        store.setKeepScreenOn(false)
        store.setDimAfter(.oneMinute)
        XCTAssertEqual(store.state, StreamingPreferences(keepScreenOn: false, dimAfter: .oneMinute))
        XCTAssertEqual(defaults.integer(forKey: StreamingPreferenceStore.dimAfterKey), 60)
        XCTAssertEqual(StreamingPreferenceStore(defaults: defaults).state, store.state, "a relaunch reads them back")
    }

    func testSettingTheSameValuesTwiceWritesOnce() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = StreamingPreferenceStore(defaults: defaults)
        store.setKeepScreenOn(false)
        store.setDimAfter(.never)
        defaults.removeObject(forKey: StreamingPreferenceStore.keepScreenOnKey)
        defaults.removeObject(forKey: StreamingPreferenceStore.dimAfterKey)
        store.setKeepScreenOn(false)
        store.setDimAfter(.never)
        XCTAssertNil(defaults.object(forKey: StreamingPreferenceStore.keepScreenOnKey), "a repeat set is a no-op")
        XCTAssertNil(defaults.object(forKey: StreamingPreferenceStore.dimAfterKey), "a repeat set is a no-op")
    }
}
