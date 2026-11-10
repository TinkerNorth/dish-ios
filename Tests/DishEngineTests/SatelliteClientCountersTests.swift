// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The session's counters as Diagnostics reads them off the client's words:
/// each datagram sent, each one opened, each one refused, and the replay
/// guard's high-water mark, all starting over with a new session.
@MainActor
final class SatelliteClientCountersTests: XCTestCase {

    func testAFreshSessionHasCountedNothing() throws {
        let client = try XCTUnwrap(DataPlaneTestHelpers.makeClient())
        defer { client.closeSocket() }
        XCTAssertEqual(client.counters(), SessionCounters(sent: 0, received: 0, dropped: 0, replayGuard: 0))
    }

    func testAnOpenedDatagramCountsAsReceivedAndMovesTheReplayGuard() throws {
        let client = try XCTUnwrap(DataPlaneTestHelpers.makeClient())
        defer { client.closeSocket() }
        client.processIncoming(DataPlaneTestHelpers.ackDatagram(counter: 1))
        client.processIncoming(DataPlaneTestHelpers.ackDatagram(counter: 2))
        XCTAssertEqual(client.counters(), SessionCounters(sent: 0, received: 2, dropped: 0, replayGuard: 2))
    }

    func testARefusedDatagramCountsAsDroppedAndLeavesTheGuardAlone() throws {
        let client = try XCTUnwrap(DataPlaneTestHelpers.makeClient())
        defer { client.closeSocket() }
        let anotherSessionsAck = DataPlaneTestHelpers.sealDownlink(
            msgType: ProtocolConstants.msgHeartbeatAck,
            payload: Data([1, 1, 0, 3, 0, 1]),
            counter: 3,
            token: DataPlaneTestHelpers.testToken + 1
        )
        client.processIncoming(DataPlaneTestHelpers.ackDatagram(counter: 2))
        client.processIncoming(Data([1, 2, 3]))
        client.processIncoming(DataPlaneTestHelpers.ackDatagram(counter: 1))
        client.processIncoming(anotherSessionsAck)
        XCTAssertEqual(client.counters(), SessionCounters(sent: 0, received: 1, dropped: 3, replayGuard: 2))
    }

    func testASendCountsAsSent() throws {
        let client = try XCTUnwrap(DataPlaneTestHelpers.makeClient())
        defer { client.closeSocket() }
        client.sendReport(controllerIndex: 0, report: GamepadReport())
        client.sendReport(controllerIndex: 0, report: GamepadReport(buttons: 1))
        XCTAssertEqual(client.counters().sent, 2)
    }

    func testTheCountersStartOverWithANewSession() throws {
        let client = try XCTUnwrap(DataPlaneTestHelpers.makeClient())
        defer { client.closeSocket() }
        client.sendReport(controllerIndex: 0, report: GamepadReport())
        client.processIncoming(DataPlaneTestHelpers.ackDatagram(counter: 1))
        client.processIncoming(Data([1, 2, 3]))
        XCTAssertTrue(client.setConnectionParams(
            host: "127.0.0.1",
            udpPort: 9,
            token: DataPlaneTestHelpers.testToken,
            sessionKey: DataPlaneTestHelpers.testKey
        ))
        XCTAssertEqual(client.counters(), SessionCounters(sent: 0, received: 0, dropped: 0, replayGuard: 0))
    }

    func testTheLatencySummaryReadsTheWindowsRoundTrips() throws {
        let client = try XCTUnwrap(DataPlaneTestHelpers.makeClient())
        defer { client.closeSocket() }
        XCTAssertEqual(client.latencySummary(), LatencySummary(p50RttMs: nil, p99RttMs: nil, samples: 0, capacity: LatencyWindow.capacity))
        let sentMs = SatelliteClient.monotonicNowMs()
        client.armLatencyPing(nowMs: sentMs)
        client.recordLatencyAck(nowMs: sentMs + 8)
        XCTAssertEqual(client.latencySummary(), LatencySummary(p50RttMs: 8, p99RttMs: 8, samples: 1, capacity: LatencyWindow.capacity))
    }
}
