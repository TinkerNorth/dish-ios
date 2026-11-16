// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// Where a PC stands with this iPhone, every step of the way: being
/// reached for, up, faltering, resting, or waiting for a PIN.
package enum ConnectionState: Equatable {
    case online(latencyMs: Int, controllers: Int)
    /// Live, but the heartbeat acks falter: the PC has stopped responding.
    case unsteady(latencyMs: Int, controllers: Int)
    /// Being reached for right now.
    case connecting
    /// `lastSeen` is nil when the PC was never reached from this install.
    case offline(lastSeen: Date?)
    case needsPairing
}

/// What a satellite can carry right now, from its capabilities probe:
/// motion while its motion backend is up, the return path while its
/// feedback is.
package struct SatelliteFeaturesFact: Equatable {
    package let motion: Bool
    package let rumble: Bool

    package init(motion: Bool, rumble: Bool) {
        self.motion = motion
        self.rumble = rumble
    }
}

/// A PC, paired or found on the network. Its kind is the fleet's
/// `ConnectionKind` from the link-tier ladder. A paired PC also carries
/// what its page shows: the controllers bound to it in the order of the
/// indices they hold, the satellite's version once probed, the protocol a
/// live session speaks, and what it can carry each way. `notice` is why the
/// last attempt the person made on it failed, carried until the next
/// attempt or until the PC is up.
package struct ConnectionFact: Equatable, Identifiable {
    package let id: String
    package let name: String
    package let address: String
    package let kind: ConnectionKind
    package let state: ConnectionState
    package let notice: ConnectionFailure?
    package let boundControllerIds: [String]
    /// Nil until the satellite was probed, and for one that reports none.
    package let satelliteVersion: String?
    /// Nil while no session is up.
    package let protocolVersion: Int?
    /// Nil until the satellite was probed.
    package let features: SatelliteFeaturesFact?

    package init(
        id: String,
        name: String,
        address: String,
        kind: ConnectionKind,
        state: ConnectionState,
        notice: ConnectionFailure? = nil,
        boundControllerIds: [String] = [],
        satelliteVersion: String? = nil,
        protocolVersion: Int? = nil,
        features: SatelliteFeaturesFact? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.kind = kind
        self.state = state
        self.notice = notice
        self.boundControllerIds = boundControllerIds
        self.satelliteVersion = satelliteVersion
        self.protocolVersion = protocolVersion
        self.features = features
    }
}

/// The one bind the apply follows: which controller on which PC, and where
/// it stands. Nil in the facts while no bind is in flight or just ended.
package struct ApplyFact: Equatable {
    package let slotId: String
    package let connectionId: String
    package let progress: ApplyProgress

    package init(slotId: String, connectionId: String, progress: ApplyProgress) {
        self.slotId = slotId
        self.connectionId = connectionId
        self.progress = progress
    }
}

/// Whether the PC a session streams to is still answering, or is being
/// reached for again at the person's asking.
package enum SessionPhase: Equatable {
    case streaming
    case stoppedResponding
    /// No session is up; the PC the person reached for, with pads bound to
    /// it, is being connected to.
    case reconnecting
    /// The PC with pads bound to it cannot be used, and the rows say why;
    /// Reconnect tries again.
    case failed(ConnectionFailure)
}

/// The live link the session accessory shows on every tab, or the one
/// being brought back.
package struct SessionFact: Equatable {
    /// The PC's connection id; empty in a fixture that names none.
    package let id: String
    package let pcName: String
    package let pads: Int
    /// Nil until the first round trip is measured, and while reconnecting.
    package let latencyMs: Int?
    package let phase: SessionPhase

    package init(id: String = "", pcName: String, pads: Int, latencyMs: Int?, phase: SessionPhase) {
        self.id = id
        self.pcName = pcName
        self.pads = pads
        self.latencyMs = latencyMs
        self.phase = phase
    }
}

/// The PC the person typed by its address this run: whether the pool is
/// reaching for it now, and why the attempt failed when it did.
package struct AddedByAddressFact: Equatable {
    package let id: String
    package let reaching: Bool
    package let failure: ConnectionFailure?

    package init(id: String, reaching: Bool, failure: ConnectionFailure?) {
        self.id = id
        self.reaching = reaching
        self.failure = failure
    }
}

/// A failure the last attempt left, shown while the PC is neither up with
/// its acks flowing nor being reached for again; a session that falters
/// shows the failure that explains it.
package func attemptNotice(_ failure: ConnectionFailure?, live: LinkState) -> ConnectionFailure? {
    switch live {
    case .connected, .connecting: nil
    case .unstable, .stale, .saved, .ready: failure
    }
}
