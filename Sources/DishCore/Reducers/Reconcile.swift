// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// Pure reconcile decision logic for the declarative session (contract
// §Session / §Enriched heartbeat ack). Free functions, IO-free — the
// protocol's self-heal rules as documentation. Ports dish-linux
// Network/Reconcile.h.
//
// The loop: every enriched ack carries (epoch, activeBitmap). When either
// drifts from what we last applied, GET /api/connections/{id}; if the applied
// view still matches desired, just adopt the new epoch (benign drift); else
// re-PUT the full desired state (self-heal ≤2 s).

import Foundation

/// One desired controller slot, reduced to what reconcile compares on:
/// index + emulation type. (caps/touchpadMode also converge via re-PUT, but
/// the server's applied view reports type, so type is the comparison key.)
package struct DesiredSlot: Equatable, Hashable {
    package let ctrlIdx: UInt8
    package let type: UInt8

    package init(ctrlIdx: UInt8, type: UInt8) {
        self.ctrlIdx = ctrlIdx
        self.type = type
    }
}

/// One applied controller from a `GET /api/connections/{id}` response.
package struct AppliedSlot: Equatable, Hashable {
    package let ctrlIdx: UInt8
    package let appliedType: UInt8
    package let active: Bool

    package init(ctrlIdx: UInt8, appliedType: UInt8, active: Bool = true) {
        self.ctrlIdx = ctrlIdx
        self.appliedType = appliedType
        self.active = active
    }
}

/// The 16-bit active-controller bitmap the client expects, derived from the
/// slots it believes are registered/live (bit ctrlIdx set). Compared against
/// the enriched-ack activeBitmap. Out-of-range indices (>15) set no bit.
package func expectedBitmap(_ registered: [DesiredSlot]) -> UInt16 {
    var bitmap: UInt16 = 0
    for slot in registered where slot.ctrlIdx <= 15 {
        bitmap |= UInt16(1) << UInt16(slot.ctrlIdx)
    }
    return bitmap
}

/// Does the enriched ack (`serverEpoch`, `serverBitmap`) indicate the
/// server's applied topology drifted from ours? `serverEpoch < 0` means no
/// enriched ack has been seen yet (don't reconcile). `serverBitmap < 0` means
/// unknown (skip the bitmap arm). Returns true when a GET-then-maybe-rePUT is
/// warranted.
package func reconcileNeeded(serverEpoch: Int, serverBitmap: Int, lastAppliedEpoch: Int, expectedBitmap: UInt16) -> Bool {
    if serverEpoch < 0 { return false }
    if serverEpoch != lastAppliedEpoch { return true }
    if serverBitmap >= 0, UInt16(truncatingIfNeeded: serverBitmap) != expectedBitmap { return true }
    return false
}

/// After GET: does the server's applied view match our desired set? When it
/// does, the drift was benign (e.g. our own standalone PUT raced an ack) and
/// the caller just adopts the new epoch; when it doesn't, the caller re-PUTs.
/// Only `active` controllers count on the applied side (an inactive slot is
/// unplugged server-side). `mouseWantsVsGrantedMatch` folds the host-feature
/// grant in: a slot toggled to mouse mid-session leaves wants≠granted until a
/// re-PUT (the grant is only computed at session PUT — contract
/// §hostFeatures), so a mismatch there also forces the converge.
package func appliedMatchesDesired(
    desired: [DesiredSlot],
    applied: [AppliedSlot],
    mouseWantsVsGrantedMatch: Bool = true
) -> Bool {
    var want = [UInt8: UInt8]()
    for slot in desired {
        want[slot.ctrlIdx] = slot.type
    }
    var have = [UInt8: UInt8]()
    for slot in applied where slot.active {
        have[slot.ctrlIdx] = slot.appliedType
    }
    return want == have && mouseWantsVsGrantedMatch
}

// MARK: - Late-slot converge

/// A session PUT snapshots the desired descriptors at send time; slots can
/// change between the snapshot and the response landing. This diff returns
/// the per-controller follow-ups to converge the live session WITHOUT
/// re-PUTting the whole thing.
package struct LateConverge: Equatable {
    /// ctrlIdx whose descriptor changed (or is new) — re-PUT via
    /// `PUT /controllers/{idx}`. Sorted ascending.
    package let resyncs: [UInt8]
    /// ctrlIdx that were sent but are no longer desired — `DELETE
    /// /controllers/{idx}`. Sorted ascending.
    package let removes: [UInt8]

    package init(resyncs: [UInt8] = [], removes: [UInt8] = []) {
        self.resyncs = resyncs
        self.removes = removes
    }
}

/// `sent` and `desired` carry index + type (the fields a descriptor change is
/// keyed on for this comparison). An entry present in `desired` but absent
/// from `sent`, or present in both with a different type, is a resync; an
/// entry in `sent` but not `desired` is a remove.
package func lateSlotConverge(sent: [DesiredSlot], desired: [DesiredSlot]) -> LateConverge {
    var sentByIdx = [UInt8: UInt8]()
    for slot in sent {
        sentByIdx[slot.ctrlIdx] = slot.type
    }
    var desiredByIdx = [UInt8: UInt8]()
    for slot in desired {
        desiredByIdx[slot.ctrlIdx] = slot.type
    }

    let resyncs = desired.filter { sentByIdx[$0.ctrlIdx] != $0.type }.map(\.ctrlIdx)
    let removes = sent.filter { desiredByIdx[$0.ctrlIdx] == nil }.map(\.ctrlIdx)
    return LateConverge(resyncs: resyncs.sorted(), removes: removes.sorted())
}

// MARK: - Send-counter exhaustion guard (contract §Crypto)

/// The UDP send counter can never wrap; a session approaching 2^32 self-heals
/// by proactively re-PUTting (fresh token/salt/key, counters back to 1).
/// Clients SHOULD re-PUT once the send counter crosses
/// `ProtocolConstants.counterRepushThreshold` (0xF0000000).
package func counterNeedsRepush(_ sendCounter: UInt32) -> Bool {
    sendCounter >= ProtocolConstants.counterRepushThreshold
}
