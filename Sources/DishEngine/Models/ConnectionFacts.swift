// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// What a PC runs to receive input.
package enum ConnectionKind: Equatable {
    case satellite
    case moonlight
}

/// Where a PC stands with this iPhone.
package enum ConnectionState: Equatable {
    case online(latencyMs: Int, controllers: Int)
    /// `lastSeen` is nil when the PC was never reached from this install.
    case offline(lastSeen: Date?)
    case needsPairing
}

/// A PC, paired or found on the network.
package struct ConnectionFact: Equatable, Identifiable {
    package let id: String
    package let name: String
    package let address: String
    package let kind: ConnectionKind
    package let state: ConnectionState

    package init(id: String, name: String, address: String, kind: ConnectionKind, state: ConnectionState) {
        self.id = id
        self.name = name
        self.address = address
        self.kind = kind
        self.state = state
    }
}

/// Whether the PC a session streams to is still answering.
package enum SessionPhase: Equatable {
    case streaming
    case stoppedResponding
}

/// The live link the session accessory shows on every tab.
package struct SessionFact: Equatable {
    package let pcName: String
    package let pads: Int
    /// Nil until the first round trip is measured.
    package let latencyMs: Int?
    package let phase: SessionPhase

    package init(pcName: String, pads: Int, latencyMs: Int?, phase: SessionPhase) {
        self.pcName = pcName
        self.pads = pads
        self.latencyMs = latencyMs
        self.phase = phase
    }
}
