// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest
@testable import DishEngine

/// A tracked lock is the mutex it wraps: it serialises its holders over the
/// value it guards, and a role's queue is a plain serial queue.
final class TrackedLockTests: XCTestCase {

    func testATrackedLockSerialisesItsHolders() {
        let lock = TrackedLock(0, "test.counter")
        Hammer.run { _ in lock.withLock { $0 += 1 } }
        XCTAssertEqual(lock.withLock { $0 }, Hammer.threads * Hammer.rounds)
    }

    func testTheRoutingTableHandsBackWhatWasSet() {
        let table = RoutingTable()
        XCTAssertNil(table.get("pad"))
        let key = SatellitePadKey(connectionId: "den", controllerIndex: 2)
        table.set(RoutingSnapshot(bySatellitePad: [key: BoundSlotRoute(slotId: "pad", flags: ForwardingFlags())]))
        XCTAssertEqual(table.boundSlot(of: key)?.slotId, "pad")
        XCTAssertEqual(table.current().bySatellitePad.count, 1)
    }

    func testARoleQueueKeepsItsLabelAndQuality() {
        let queue = ThreadRole.input.queue(label: "test.roleQueue", qos: .userInteractive)
        XCTAssertEqual(queue.label, "test.roleQueue")
        XCTAssertEqual(queue.qos, .userInteractive)
    }

    func testEveryRoleHasItsOwnName() {
        let names = ThreadRole.allCases.map(\.name)
        XCTAssertEqual(Set(names).count, ThreadRole.allCases.count)
        XCTAssertEqual(ThreadRole.input.name, "Input")
    }
}
