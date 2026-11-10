// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The controller index a pad holds on the PC it is bound to: the number the
/// wire carries and the satellite's return paths name the pad by.
package struct SlotIndex: Hashable, ExpressibleByIntegerLiteral {
    package let value: Int

    package init(_ value: Int) {
        self.value = value
    }

    package init(integerLiteral value: Int) {
        self.init(value)
    }
}

/// Where a pad's reports go. Called on the pad's handler queue; must not
/// block, allocate or hop. The satellite's client conforms to it. The feed
/// stamps what the wire carries beside a sample: a motion sample's delta
/// from the last one let through, and a touch's publish instant, since
/// GameController surfaces no per-event timestamp.
package protocol PadSink: Sendable {
    func send(_ report: GamepadReport, slot: SlotIndex)
    func send(_ motion: MotionSample, timestampDeltaUs: UInt32, slot: SlotIndex)
    func send(_ touch: TouchpadSample, eventTimeMs: UInt32, slot: SlotIndex)
    func send(battery: BatteryReading, slot: SlotIndex)
}

/// Where a bound pad's input goes and which of its streams may flow: the
/// sink, the pad's index there, and the switches in force for that
/// controller, global and its own folded together on the main actor.
package struct Route {
    package let sink: any PadSink
    package let slot: SlotIndex
    package let flags: ForwardingFlags

    package init(sink: any PadSink, slot: SlotIndex, flags: ForwardingFlags) {
        self.sink = sink
        self.slot = slot
        self.flags = flags
    }
}

/// One route as the mailbox carries it to the publishing thread.
package final class RouteBox: Sendable {
    package let route: Route?

    package init(_ route: Route?) {
        self.route = route
    }
}
