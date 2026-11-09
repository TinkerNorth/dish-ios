// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// One pad on one satellite: the connection and the controller index the
/// satellite's return paths name it by.
package struct SatellitePadKey: Hashable {
    package let connectionId: String
    package let controllerIndex: Int

    package init(connectionId: String, controllerIndex: Int) {
        self.connectionId = connectionId
        self.controllerIndex = controllerIndex
    }
}

/// A satellite's side of the same table: the slot bound to one of its
/// controller indices and the switches in force for that controller, for
/// the return paths.
package struct BoundSlotRoute {
    package let slotId: String
    package let flags: ForwardingFlags

    package init(slotId: String, flags: ForwardingFlags) {
        self.slotId = slotId
        self.flags = flags
    }
}

/// The two views of one binding table, built together on the main actor so
/// they can never disagree.
package struct RoutingSnapshot {
    package var bySlot: [String: Route] = [:]
    package var bySatellitePad: [SatellitePadKey: BoundSlotRoute] = [:]

    package init(bySlot: [String: Route] = [:], bySatellitePad: [SatellitePadKey: BoundSlotRoute] = [:]) {
        self.bySlot = bySlot
        self.bySatellitePad = bySatellitePad
    }
}

/// The routing table for the cold readers: written on the main actor when
/// bindings or a switch change; read by the receive loop's return paths and
/// by the tests. No report reads it: each pad's feed holds its own route.
package final class RoutingTable: Sendable {
    private let snapshot = TrackedLock(RoutingSnapshot(), "routing.table")

    package init() {}

    package func get(_ slotId: String) -> Route? {
        snapshot.withLock { $0.bySlot[slotId] }
    }

    package func boundSlot(of pad: SatellitePadKey) -> BoundSlotRoute? {
        snapshot.withLock { $0.bySatellitePad[pad] }
    }

    package func current() -> RoutingSnapshot {
        snapshot.withLock { $0 }
    }

    package func set(_ next: RoutingSnapshot) {
        snapshot.withLock { $0 = next }
    }
}

/// From the main actor's routing to the hot path: one snapshot fills the
/// table and gives every pad's feed its route, so a report reads no table
/// and takes no lock on its way to the wire.
@MainActor
package final class InputRouting {
    package let table = RoutingTable()

    package init() {}

    /// Publishes `snapshot` to the table and to every feed. Call it again
    /// when a connection's client changes.
    package func publish(_ snapshot: RoutingSnapshot, to processor: GamepadInputProcessor) {
        table.set(snapshot)
        let routes = snapshot.bySlot
        processor.route { routes[$0] }
    }

    package func republish(to processor: GamepadInputProcessor) {
        publish(table.current(), to: processor)
    }
}
