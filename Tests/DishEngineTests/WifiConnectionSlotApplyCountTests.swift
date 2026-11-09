// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The count of the satellite's confirmations that a slot is plugged, kept
/// per slot: one per confirmation, none without a bound slot, never rewound,
/// another pad's confirmation never counted.
@MainActor
final class WifiConnectionSlotApplyCountTests: XCTestCase {

    private func connection() -> WifiConnection {
        let server = DiscoveredServer(name: "Desk", ip: "10.0.0.1", udpPort: 9876, pairPort: 9443, httpPort: 9443, machineId: "desk")
        return WifiConnection(id: "desk", server: server)
    }

    func testEveryConfirmationCountsAndNoneWithoutABoundSlot() {
        let conn = connection()
        conn.markSlotApplied("slot")
        XCTAssertEqual(conn.slotTable.applyCount(of: "slot"), 0, "nothing to plug")
        XCTAssertFalse(conn.isSlotApplied("slot"))

        conn.attachSlot("slot", controllerType: 0, capabilities: .none, emulateAs: .xboxWireless)
        conn.markSlotApplied("slot")
        conn.markSlotApplied("slot")
        XCTAssertEqual(conn.slotTable.applyCount(of: "slot"), 2, "a re-PUT the satellite confirms is a fresh pad too")
        XCTAssertTrue(conn.isSlotApplied("slot"))
    }

    func testDetachingNeverRewindsTheCount() {
        let conn = connection()
        conn.attachSlot("slot", controllerType: 0, capabilities: .none, emulateAs: .xboxWireless)
        conn.markSlotApplied("slot")
        conn.detachSlot("slot")
        XCTAssertFalse(conn.isSlotApplied("slot"))
        XCTAssertEqual(conn.slotTable.applyCount(of: "slot"), 1)
        conn.attachSlot("slot", controllerType: 0, capabilities: .none, emulateAs: .xboxWireless)
        conn.markSlotApplied("slot")
        XCTAssertEqual(conn.slotTable.applyCount(of: "slot"), 2)
    }

    /// An apply watches the count move: each confirmation of that slot
    /// moves it, another pad's confirmation does not.
    func testTheCountMovesOncePerConfirmationOfThatSlotAlone() {
        let conn = connection()
        conn.attachSlot("slot", controllerType: 0, capabilities: .none, emulateAs: .xboxWireless)
        conn.attachSlot("other", controllerType: 0, capabilities: .none, emulateAs: .xboxWireless)
        var seen: [Int] = []
        conn.markSlotApplied("slot")
        seen.append(conn.applyCount(of: "slot"))
        conn.markSlotApplied("other")
        seen.append(conn.applyCount(of: "slot"))
        conn.markSlotApplied("slot")
        seen.append(conn.applyCount(of: "slot"))
        XCTAssertEqual(seen, [1, 1, 2], "the other pad's confirmation is not this one's")
    }
}
