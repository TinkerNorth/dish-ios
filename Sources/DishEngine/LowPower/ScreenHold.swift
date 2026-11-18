// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Whether Dish holds the screen on: a session streaming with a binding
/// that is active (a pad iOS lists, or the on-screen controller while its
/// screen is up) and Keep screen on set. A session being brought back, one
/// that stopped responding or failed, a bare connection and a binding whose
/// pad is away let the phone lock like any other app. The low-power
/// countdown runs exactly while the screen is held.
package func screenHeld(session: SessionFact?, keepScreenOn: Bool) -> Bool {
    guard let session, keepScreenOn else { return false }
    return streams(session.phase) && session.active > 0
}

private func streams(_ phase: SessionPhase) -> Bool {
    switch phase {
    case .streaming: true
    case .stoppedResponding, .reconnecting, .failed: false
    }
}
