// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The client's own view of a host's session for the support file, read off
// the connection and its client on the main actor: each slot with what the
// host last answered for it, the last heartbeat ack, the round trips, and
// the datagrams by kind. Nil while no session is up.

import DishCore
import Foundation

/// A satellite's session; `records` names each slot's record id, `slugs`
/// the cached catalog's slug for each wire type.
@MainActor
func satelliteSessionBundle(of conn: WifiConnection, records: [String: String], slugs: [Int: String]) -> BundleSession? {
    guard conn.hasLiveSession else { return nil }
    let slots = conn.slotsInIndexOrder.map { entry in
        BundleSessionSlot(
            index: entry.descriptor.ctrlIdx,
            record: records[entry.slotId],
            requestedType: slotTypeWord(Int(entry.descriptor.type), slugs: slugs),
            appliedType: entry.slot.lastApply.map { slotTypeWord($0.appliedType, slugs: slugs) },
            backend: entry.slot.lastApply?.backend,
            result: entry.slot.lastApply?.result,
            touchpadMode: entry.descriptor.touchpadMode.wireName
        )
    }
    let latency = conn.client?.latencySummary()
    let rtt = latency.map { BundleRtt(p50Ms: $0.p50RttMs, p99Ms: $0.p99RttMs, samples: $0.samples) }
    return BundleSession(
        slots: slots,
        ack: conn.lastHeartbeatAck.map(bundleAck),
        rtt: rtt,
        sent: conn.client?.tally.sent,
        received: conn.client?.tally.received
    )
}

private func bundleAck(_ ack: HeartbeatAck) -> BundleAck {
    BundleAck(
        backendAvailable: ack.backendAvailable,
        activeControllers: Int(ack.activeCount),
        epoch: Int(ack.epoch),
        activeBitmap: ack.bitmap
    )
}

/// A Moonlight host's session: the pads it holds by number, the control
/// link's round trip, and the reports sent on them. The host answers no
/// apply and acks with no facts, so those are null; nil while idle.
func moonlightSessionBundle(_ facts: MoonlightHostDiagnostics, records: [String: String]) -> BundleSession? {
    guard facts.phase != .idle else { return nil }
    let slots = facts.pads.map { pad in
        BundleSessionSlot(
            index: Int(pad.number),
            record: records[pad.slotId],
            requestedType: String(pad.type),
            appliedType: nil,
            backend: nil,
            result: nil,
            touchpadMode: nil
        )
    }
    let reports = facts.pads.reduce(0) { $0 + UInt64($1.reports) }
    return BundleSession(
        slots: slots,
        ack: nil,
        rtt: facts.controlRoundTripMs.map { BundleRtt(p50Ms: Double($0), p99Ms: nil, samples: nil) },
        sent: BundleSent(input: reports, motion: nil, battery: nil, pointer: nil, mic: nil, heartbeat: nil),
        received: nil
    )
}
