// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
@testable import DishEngine

/// The return paths as a satellite client's receive loop drives them: each
/// of a connection's four controller indices bound to a slot named for it
/// (`pad-0` … `pad-3`), every switch on, the commands landing on recording
/// actuators through the pads' feedback queue.
@MainActor
final class FeedbackRecorder {
    let actuators = RecordingActuators()
    let feedback: PadFeedback
    let routes: FeedbackRoutes

    init(connectionId: String = "sat", flags: ForwardingFlags = ForwardingFlags()) {
        feedback = PadFeedback(actuators: actuators, queue: DispatchSerialQueue(label: "test.feedback"))
        var snapshot = RoutingSnapshot()
        for index in 0 ..< SatelliteSlots.maxPerSatellite {
            let pad = SatellitePadKey(connectionId: connectionId, controllerIndex: index)
            snapshot.bySatellitePad[pad] = BoundSlotRoute(slotId: "pad-\(index)", flags: flags)
        }
        routes = FeedbackRoutes(connectionId: connectionId, snapshot: snapshot, global: flags, feedback: feedback)
    }

    func install(on client: SatelliteClient) {
        client.setFeedbackRoutes(routes)
    }

    /// What reached the actuators once the feedback queue drained.
    var actuations: [RecordingActuators.Actuation] {
        feedback.queue.sync {}
        return actuators.actuations
    }
}

/// The close reasons a client's receive loop relayed, on whatever thread.
final class CloseRecorder: Sendable {
    private let log = Locked<[CloseReason]>([])

    func install(on client: SatelliteClient) {
        client.setSessionCloseHandler { [log] reason in log.mutate { $0.append(reason) } }
    }

    var reasons: [CloseReason] {
        log.get()
    }
}
