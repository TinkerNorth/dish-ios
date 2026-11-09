// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The satellite's controller indices a connection can carry.
private let padsPerSatellite = 4

/// Which return paths a pad acts on: each kind behind its switch.
package enum ReturnPathRouting {
    /// A rumble drives the haptics only behind the rumble switch.
    package static func shouldVibrate(flags: ForwardingFlags) -> Bool {
        flags.rumble
    }

    /// A light-bar colour reaches the pad only behind the light-bar switch.
    package static func shouldApplyLightbar(flags: ForwardingFlags) -> Bool {
        flags.lightbar
    }
}

/// One connection's feedback routes, fixed when they are built: the record
/// and the switches in force for each controller index, and the global
/// switches. Its handlers run on the receive loop that opened each command
/// and only read it. The commands arrive as the wire's fields; the receive
/// loop that decodes them calls these.
package struct FeedbackRoutes {
    package struct Route {
        package let pad: FeedbackPad
        package let flags: ForwardingFlags
    }

    package let byIndex: [Route?]
    package let global: ForwardingFlags

    /// The routes `snapshot` gives the connection's indices.
    @MainActor
    package init(connectionId: String, snapshot: RoutingSnapshot, global: ForwardingFlags, feedback: PadFeedback) {
        var byIndex = [Route?](repeating: nil, count: padsPerSatellite)
        for (pad, bound) in snapshot.bySatellitePad
            where pad.connectionId == connectionId && byIndex.indices.contains(pad.controllerIndex)
        {
            byIndex[pad.controllerIndex] = Route(pad: feedback.pad(for: bound.slotId), flags: bound.flags)
        }
        self.byIndex = byIndex
        self.global = global
    }

    /// The pad bound to the index, or nil for an index no pad holds.
    package func route(_ controllerIndex: UInt8) -> Route? {
        let index = Int(controllerIndex)
        return byIndex.indices.contains(index) ? byIndex[index] : nil
    }

    /// Rumble is the bound controller's own switch, folded with the global one.
    package func rumble(controllerIndex: UInt8, strong: UInt16, weak: UInt16, durationMs: UInt16) {
        guard let route = route(controllerIndex), ReturnPathRouting.shouldVibrate(flags: route.flags) else { return }
        route.pad.post(rumbleStrong: strong, weak: weak, durationMs: durationMs)
    }

    /// The light bar needs the global switch and the controller's own.
    package func lightbar(controllerIndex: UInt8, red: UInt8, green: UInt8, blue: UInt8) {
        guard ReturnPathRouting.shouldApplyLightbar(flags: global), let route = route(controllerIndex) else { return }
        guard ReturnPathRouting.shouldApplyLightbar(flags: route.flags) else { return }
        route.pad.post(lightbarRed: red, green: green, blue: blue)
    }

    package func triggerEffects(controllerIndex: UInt8, left: [UInt8], right: [UInt8]) {
        guard let route = route(controllerIndex), route.flags.triggerEffects else { return }
        route.pad.post(triggerEffectsLeft: left, right: right)
    }

    /// The player the LED mask spells, as the framework drives it by index.
    package func playerLeds(controllerIndex: UInt8, player: Int) {
        guard let route = route(controllerIndex), route.flags.playerLeds else { return }
        route.pad.post(player: player)
    }
}

/// A connection that takes the return paths: the satellite's session in the
/// network wave. It keeps the routes it was last handed and opens each
/// command against them.
@MainActor
package protocol FeedbackRouteTarget: AnyObject {
    func setFeedbackRoutes(_ routes: FeedbackRoutes)
}

/// Routes the satellite's return paths (rumble, light bar, trigger effects,
/// player LEDs) from a connection to the controller bound to the index each
/// command names, so a satellite carrying four pads rumbles the right one.
/// Every routing change hands each connection fresh `FeedbackRoutes`; the
/// receive loop gates each command against them and posts it to the pad's
/// record, and the feedback queue actuates it: one hop, no lock, no main
/// actor.
@MainActor
package final class ReturnPathRouter {
    private let feedback: PadFeedback
    private var pool: [String: any FeedbackRouteTarget] = [:]
    private var snapshot = RoutingSnapshot()
    private var global = ForwardingFlags()

    package init(feedback: PadFeedback) {
        self.feedback = feedback
    }

    /// The pool changed: the connections it holds get the current routes.
    package func wire(_ pool: [String: any FeedbackRouteTarget]) {
        self.pool = pool
        install()
    }

    /// The bindings or a switch changed.
    package func route(_ snapshot: RoutingSnapshot, global: ForwardingFlags) {
        self.snapshot = snapshot
        self.global = global
        install()
    }

    private func install() {
        for (id, connection) in pool {
            connection.setFeedbackRoutes(FeedbackRoutes(connectionId: id, snapshot: snapshot, global: global, feedback: feedback))
        }
    }
}
