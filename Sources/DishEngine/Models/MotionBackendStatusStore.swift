// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// The satellite's motion word per binding, as the apply results report it.
/// Written by the connection manager after every descriptor PUT, cleared
/// when the binding goes, read by the controller page's Motion row.
@MainActor
package final class MotionBackendStatusStore {
    private let source = StateSource<[SlotKey: MotionBackendStatus]>(initial: [:])

    package init() {}

    package var state: [SlotKey: MotionBackendStatus] {
        source.state
    }

    package func statusFor(_ key: SlotKey) -> MotionBackendStatus? {
        state[key]
    }

    package func setStatus(_ status: MotionBackendStatus, for key: SlotKey) {
        source.updateState { current in
            var next = current
            next[key] = status
            return next
        }
    }

    package func clear(_ key: SlotKey) {
        source.updateState { current in
            var next = current
            next.removeValue(forKey: key)
            return next
        }
    }

    package func clearConnection(_ connectionId: String) {
        source.updateState { current in
            current.filter { $0.key.connectionId != connectionId }
        }
    }
}
