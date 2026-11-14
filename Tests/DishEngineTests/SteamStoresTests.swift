// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The two stores Steam Controllers over Bluetooth keep: the opt-in, off on a
/// fresh install, and each pad's chosen trackpad pick in dish-mac's rows.
@MainActor
final class SteamStoresTests: XCTestCase {

    func testTheOptInIsOffOnAFreshInstallAndKeptOnceSet() throws {
        let defaults = try TestDefaults.fresh(self)
        XCTAssertFalse(SteamBluetoothPreferenceStore(defaults: defaults).enabled)
        SteamBluetoothPreferenceStore(defaults: defaults).setEnabled(true)
        XCTAssertTrue(SteamBluetoothPreferenceStore(defaults: defaults).enabled, "read back on the next launch")
    }

    func testAChosenPickIsKeptInDishMacsRows() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = TrackpadPickStore(defaults: defaults)
        XCTAssertNil(store.pick(for: "ble:a"), "an unchosen pad follows its model's default")
        store.setPick(.stick, for: "ble:a")
        store.setPick(.pad, for: "ble:b")
        XCTAssertEqual(
            defaults.string(forKey: "touchpad_mode_preferences"),
            #"[{"mode":"stick","slotId":"ble:a"},{"mode":"ds4","slotId":"ble:b"}]"#
        )
        XCTAssertEqual(TrackpadPickStore(defaults: defaults).pick(for: "ble:a"), .stick)
    }

    func testARowThatIsNoPickReadsAsNothingChosen() {
        XCTAssertEqual(TrackpadPickStore.parse(#"[{"slotId":"a","mode":"banana"},{"slotId":"","mode":"ds4"},{"mode":"ds4"}]"#), [:])
        XCTAssertEqual(TrackpadPickStore.parse("garbled"), [:])
        XCTAssertEqual(TrackpadPickStore.parse(nil), [:])
    }
}
