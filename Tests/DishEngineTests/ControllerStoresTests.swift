// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The "Emulate as" pick and the dead zones, each stored per pad.
@MainActor
final class ControllerStoresTests: XCTestCase {

    func testAPickIsKeptPerPadAndClearedBackToTheFamily() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = ControllerTypeStore(defaults: defaults)
        XCTAssertNil(store.typeFor("pad"))
        store.setType(.dualShock4, for: "pad")
        XCTAssertEqual(ControllerTypeStore(defaults: defaults).typeFor("pad"), .dualShock4)
        XCTAssertEqual(defaults.dictionary(forKey: "emulated_type_preferences") as? [String: String], ["pad": "dualshock4"])
        store.clear("pad")
        XCTAssertNil(ControllerTypeStore(defaults: defaults).typeFor("pad"))
    }

    func testEveryTypeHasAStoredWordThatReadsBackAndAnUnknownWordIsNoPick() throws {
        for pad in EmulatedPad.allCases {
            XCTAssertEqual(emulatedPad(storedWord: storedWord(pad)), pad)
        }
        let defaults = try TestDefaults.fresh(self)
        defaults.set(["pad": "gamecube", "other": "xbox"], forKey: "emulated_type_preferences")
        XCTAssertEqual(ControllerTypeStore(defaults: defaults).state, ["other": .xboxWireless])
    }

    func testDeadzonesAreStoredUnderTheDesktopsKeysAndAResetForgetsThem() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = DeadzonePreferenceStore(defaults: defaults)
        XCTAssertEqual(store.zones(for: "pad"), .defaults)
        let tuned = DeadzoneSetting(stickFlat: 1000, triggerFlat: 20)
        store.setZones(tuned, for: "pad")
        XCTAssertEqual(defaults.string(forKey: "deadzone:pad"), #"{"s":1000,"t":20}"#)
        XCTAssertEqual(DeadzonePreferenceStore(defaults: defaults).zones(for: "pad"), tuned)
        store.reset("pad")
        XCTAssertNil(defaults.string(forKey: "deadzone:pad"))
        XCTAssertEqual(DeadzonePreferenceStore(defaults: defaults).zones(for: "pad"), .defaults)
    }
}
