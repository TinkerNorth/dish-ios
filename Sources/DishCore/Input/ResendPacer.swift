// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

/// The pacing gate of an on-screen control's resend loop (Android's
/// `ResendPacer`). Real input is sent as it happens and never passes here;
/// a resend exists only to heal a lost edge over plain UDP, the last frame
/// of a gesture (a button up, a finger up, a stick back to centre) that no
/// later frame would correct. A changed state is re-sent on
/// `edgeBurstResends` ticks in a row, then the stream idles at a keepalive.
package struct ResendPacer: Equatable {
    /// A lost edge heals at the next tick, a double loss at the one after.
    package static let edgeBurstResends = 3
    /// The loop's tick: 50 ms, as the overlays tick on Android.
    package static let tickIntervalNs: UInt64 = 50_000_000
    package static let keepaliveIntervalNs: UInt64 = 1_000_000_000

    private var burstLeft = 0
    private var lastSendNs: UInt64 = 0

    package init() {}

    /// Whether this tick resends, given whether the state changed since the
    /// last tick: a change opens a burst, a burst runs out one tick at a
    /// time, and an idle stream sends once a keepalive interval.
    package mutating func resendDue(changed: Bool, nowNs: UInt64) -> Bool {
        if changed {
            burstLeft = Self.edgeBurstResends - 1
        } else if burstLeft > 0 {
            burstLeft -= 1
        } else if nowNs &- lastSendNs < Self.keepaliveIntervalNs {
            return false
        }
        lastSendNs = nowNs
        return true
    }
}
