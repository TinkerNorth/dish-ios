// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The feedback contract: every step a link can be at, every way a PC a
/// pad is bound to can answer, every phase of the session and every
/// failure the pool can report has its own words, so nothing under the
/// hood happens without the person seeing it.
final class FeedbackTests: XCTestCase {

    private static let now = FactsFixture.now

    private static let everyConnectionState: [ConnectionState] = [
        .online(latencyMs: 4, controllers: 1),
        .unsteady(latencyMs: 40, controllers: 1),
        .connecting,
        .offline(lastSeen: nil),
        .needsPairing
    ]

    private func pc(_ state: ConnectionState, notice: ConnectionFailure? = nil) -> ConnectionFact {
        ConnectionFact(id: "lr", name: "Living Room PC", address: "192.168.1.24", kind: .satellite, state: state, notice: notice)
    }

    func testEveryStepOfALinkHasItsOwnLineAndMark() {
        let lines = Self.everyConnectionState.map { connectionLine(pc($0), now: Self.now) }
        XCTAssertEqual(Set(lines).count, Self.everyConnectionState.count, "\(lines)")
        XCTAssertEqual(
            Self.everyConnectionState.map { connectionMark(pc($0)) },
            [.dot(DishTheme.success), .dot(DishTheme.error), .busy, .dot(DishTheme.muted), .dot(DishTheme.warning)]
        )
    }

    /// A failure speaks over the state, in the error colour, whatever the state.
    func testAFailureSpeaksOverEveryRestingState() {
        for state in [ConnectionState.offline(lastSeen: nil), .needsPairing, .unsteady(latencyMs: 40, controllers: 1)] {
            let failed = pc(state, notice: .repairNeeded)
            XCTAssertEqual(connectionLine(failed, now: Self.now), "This satellite no longer recognizes this device. Re-pair needed.")
            XCTAssertEqual(connectionLineColor(failed), DishTheme.error)
            XCTAssertEqual(connectionMark(failed), .dot(DishTheme.error))
        }
    }

    func testEveryHealthOfAPadsPCHasItsOwnMark() {
        let marks = [LinkHealth.online, .connecting, .lost].map { destinationMark($0) }
        XCTAssertEqual(marks, [.dot(DishTheme.success), .busy, .dot(DishTheme.error)])
        XCTAssertEqual(destinationMark(nil), .dot(DishTheme.muted))
        XCTAssertEqual(
            [LinkHealth.online, .connecting, .lost].map { destinationDot($0) },
            [DishTheme.success, DishTheme.warning, DishTheme.error]
        )
    }

    func testEveryPhaseOfTheSessionHasItsOwnBar() {
        let phases: [SessionPhase] = [.streaming, .stoppedResponding, .reconnecting, .failed(.dataPathBlocked)]
        let bars = phases.map { sessionBarState(SessionFact(pcName: "Living Room PC", pads: 1, latencyMs: nil, phase: $0)) }
        XCTAssertEqual(bars.compactMap(\.self).count, phases.count)
        XCTAssertEqual(Set(bars.map(String.init(describing:))).count, phases.count)
    }

    func testEveryPhaseOfTheSessionHasItsOwnPill() {
        let phases: [SessionPhase] = [.streaming, .stoppedResponding, .reconnecting, .failed(.sessionReplaced)]
        let pills = phases.map { playPill(SessionFact(pcName: "Living Room PC", pads: 1, latencyMs: nil, phase: $0)) }
        XCTAssertEqual(Set(pills.map { $0?.detail }).count, phases.count)
        XCTAssertEqual(pills.map { $0?.mark }, [.dot(DishTheme.success), .dot(DishTheme.error), .busy, .dot(DishTheme.error)])
    }

    func testEveryFailureHasItsOwnWords() {
        let failures: [ConnectionFailure] = [
            .identityChanged, .protocolMismatch, .dishUpdateRequired, .satelliteUpdateRequired, .approvalDeclined,
            .approvalTimedOut, .repairNeeded, .unreachable(detail: ""), .noSharedKey, .sessionRefused(detail: nil),
            .controllerNotApplied, .noServersFound, .localNetworkDenied, .pairingRejected(detail: nil), .dataPathBlocked,
            .sessionReplaced
        ]
        let words = failures.map { connectionFailureText($0, name: "Den PC") }
        XCTAssertEqual(Set(words).count, failures.count, "\(words)")
    }
}
