// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// One bound pad's way back from a host: its feedback record and the
/// switches in force for it, built on the main actor whenever the routing
/// changes, read on the transport's queue.
struct MoonlightFeedbackRoute {
    let pad: FeedbackPad
    let flags: ForwardingFlags
}

/// What a Moonlight host says back, landed on the pad bound to the number
/// it names; the sibling of ReturnPathRouter. Body rumble and trigger
/// rumble are two host streams onto one pad's two motors, folded per motor
/// (never last-writer-wins, never a sum) behind the controller's Rumble
/// switch; the lamp follows the Light bar switches. A Moonlight rumble has
/// no duration: it holds until the host sends the next, so each is
/// delivered for as long as the actuator allows and a session that drops
/// mid-buzz stops on its own. The gate runs on the transport's queue
/// against the routes the main actor last built, and posts to the pad's
/// feedback record: one hop to the feedback queue, no main actor.
@MainActor
final class MoonlightFeedbackRouter {
    nonisolated static let rumbleHoldMs: UInt16 = 1500

    /// The routes by slot and the global switches, as of the last routing.
    private struct Routes {
        var bySlot: [String: MoonlightFeedbackRoute] = [:]
        var global = ForwardingFlags()
    }

    private let feedback: PadFeedback
    private nonisolated let routes = TrackedLock(Routes(), "moonlight.feedbackRoutes")
    private nonisolated let mixes = TrackedLock<[String: MoonlightRumbleMix]>([:], "moonlight.rumbleMixes")
    /// Hosts already wired, pruned to the pool on every pool change so a
    /// forgotten host that comes back under the same id is wired again.
    private var wired: Set<String> = []

    init(feedback: PadFeedback) {
        self.feedback = feedback
    }

    /// Wire every host in the pool once, and forget the ones that left.
    func wire(_ pool: [String: MoonlightConnection]) {
        wired.formIntersection(pool.keys)
        for (id, conn) in pool where !wired.contains(id) {
            wired.insert(id)
            let link = conn.link
            conn.setFeedbackHandler { [weak self] event in self?.arrived(event, link: link) }
        }
    }

    /// The bindings or a switch changed: every bound slot gets its record
    /// and its switches, whichever kind of PC it is bound to, since a host's
    /// link names only the slots it carries.
    func route(_ snapshot: RoutingSnapshot, global: ForwardingFlags) {
        var next = Routes(global: global)
        for (slotId, route) in snapshot.bySlot {
            next.bySlot[slotId] = MoonlightFeedbackRoute(pad: feedback.pad(for: slotId), flags: route.flags)
        }
        routes.withLock { $0 = next }
    }

    /// Transport queue: the slot the number names, the switch in force for it, then the hop.
    private nonisolated func arrived(_ event: MoonlightEvent, link: MoonlightPadLink) {
        switch event {
        case let .rumble(controller, low, high):
            rumble(link, controller: controller) { $0.withBody(strong: low, weak: high) }
        case let .rumbleTriggers(controller, left, right):
            rumble(link, controller: controller) { $0.withTriggers(left: left, right: right) }
        case let .rgbLed(controller, red, green, blue):
            guard let slotId = link.slot(forController: controller), let route = lightbarRoute(slotId) else { return }
            route.pad.post(lightbarRed: red, green: green, blue: blue)
        case .motionRequest, .termination, .unknown:
            break
        }
    }

    /// Low frequency is the large motor, which the actuators call strong.
    private nonisolated func rumble(
        _ link: MoonlightPadLink,
        controller: UInt16,
        fold: (MoonlightRumbleMix) -> MoonlightRumbleMix
    ) {
        guard let slotId = link.slot(forController: controller) else { return }
        let mixed = mixes.withLock { mixes -> (strong: UInt16, weak: UInt16) in
            let next = fold(mixes[slotId] ?? MoonlightRumbleMix())
            mixes[slotId] = next
            return next.mixed
        }
        guard let route = routes.withLock({ $0.bySlot[slotId] }), ReturnPathRouting.shouldVibrate(flags: route.flags) else { return }
        route.pad.post(rumbleStrong: mixed.strong, weak: mixed.weak, durationMs: Self.rumbleHoldMs)
    }

    /// The light bar needs the global switch and the controller's own.
    private nonisolated func lightbarRoute(_ slotId: String) -> MoonlightFeedbackRoute? {
        let (route, global) = routes.withLock { ($0.bySlot[slotId], $0.global) }
        guard let route, ReturnPathRouting.shouldApplyLightbar(flags: global),
              ReturnPathRouting.shouldApplyLightbar(flags: route.flags) else { return nil }
        return route
    }
}
