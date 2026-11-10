// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// A binding's identity for the per-slot stores: the PC and the pad.
package struct SlotKey: Hashable {
    package let connectionId: String
    package let slotId: String

    package init(connectionId: String, slotId: String) {
        self.connectionId = connectionId
        self.slotId = slotId
    }
}

/// The satellite's word on a slot's motion, from the apply result: whether
/// the host has a motion sink for the slot's type and whether its motion
/// backend is healthy. Both must hold for motion to land.
package struct MotionBackendStatus: Hashable {
    package let sinkSupportedForType: Bool
    package let backendOk: Bool

    package init(sinkSupportedForType: Bool, backendOk: Bool) {
        self.sinkSupportedForType = sinkSupportedForType
        self.backendOk = backendOk
    }

    package var effective: Bool {
        sinkSupportedForType && backendOk
    }
}
