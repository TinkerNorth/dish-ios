// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The slot table's word on the mouse: a slot asks for it only while the
/// phone lends it the mouse screen and the host grants mouse control, and
/// the session wants the feature while any slot asks.
final class SatelliteSlotTableTests: XCTestCase {

    private func table(hostMouseControl: Bool, surface: PhoneSurface?) -> SatelliteSlotTable {
        var table = SatelliteSlotTable()
        table.attach("xbox", controllerType: 0, capabilities: ControllerCapabilities(hasRumble: true), emulateAs: .xboxWireless)
        table.hostMouseControl = hostMouseControl
        table.slotFlags = ["xbox": ForwardingFlags(phoneSurface: surface)]
        return table
    }

    func testTheMouseScreenOnASlotAsksTheHostForTheMouseWhenItGrantsIt() {
        let asked = table(hostMouseControl: true, surface: .mouse)
        XCTAssertEqual(asked.descriptor(for: "xbox")?.touchpadMode, .mouse)
        XCTAssertTrue(asked.wantsMouseControl)
    }

    func testAHostThatGrantsNoMouseIsNotAsked() {
        let refused = table(hostMouseControl: false, surface: .mouse)
        XCTAssertEqual(refused.descriptor(for: "xbox")?.touchpadMode, .off)
        XCTAssertFalse(refused.wantsMouseControl)
    }

    func testASlotWithNoScreenLentAsksForNothing() {
        let quiet = table(hostMouseControl: true, surface: nil)
        XCTAssertEqual(quiet.descriptor(for: "xbox")?.touchpadMode, .off, "an Xbox pad has no touchpad of its own")
        XCTAssertFalse(quiet.wantsMouseControl)
    }

    func testTheCatalogsWordOnATypeIsKeptPerSlot() {
        var table = table(hostMouseControl: false, surface: nil)
        XCTAssertTrue(table.typeOffersDs4(for: "xbox"), "offered until the catalog says otherwise")
        XCTAssertTrue(table.typeOffersDs4(for: "unbound"), "a slot not bound refuses nothing")
        table.setTypeOffersDs4(false, for: "xbox")
        XCTAssertFalse(table.typeOffersDs4(for: "xbox"))
    }
}
