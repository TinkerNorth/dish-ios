// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The session the accessory shows: none while nothing is up, the live
/// satellite with its pads and its latency once one is, stopped responding
/// when its acks falter, and Reconnect bringing it back.
@MainActor
final class AppModelSessionTests: XCTestCase {

    private var fixture: SatelliteModelFixture!

    override func setUp() async throws {
        fixture = try SatelliteModelFixture(self)
    }

    override func tearDown() async throws {
        fixture?.tearDown()
        fixture = nil
    }

    func testNoSessionWhileNothingIsUp() {
        XCTAssertNil(fixture.model.shellFacts.session)
    }

    func testALiveSatelliteStreamsWithItsPadsAndTheLatencyOffItsWindow() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        let measured = await fixture.waitUntil(timeout: 8) { self.fixture.model.shellFacts.session?.latencyMs != nil }
        XCTAssertTrue(measured, "the window seeds from the heartbeat acks")
        let session = fixture.model.shellFacts.session
        XCTAssertEqual(session?.pcName, "Den PC")
        XCTAssertEqual(session?.pads, 1)
        XCTAssertEqual(session?.phase, .streaming)
    }

    func testFalteringAcksReadAsStoppedResponding() async throws {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        let conn = try XCTUnwrap(fixture.network.wifi.get(fixture.serverId))
        try XCTUnwrap(conn.client).missedAcks.set(ProtocolConstants.heartbeatMissNotResponding)
        conn.aliveTick()
        XCTAssertEqual(fixture.model.shellFacts.session?.phase, .stoppedResponding)
    }

    func testReconnectClosesAFalteringSessionAndOpensItAgain() async throws {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        let conn = try XCTUnwrap(fixture.network.wifi.get(fixture.serverId))
        let first = try XCTUnwrap(conn.client)
        first.missedAcks.set(ProtocolConstants.heartbeatMissNotResponding)
        conn.aliveTick()
        fixture.model.reconnect()
        let again = await fixture.waitUntil { conn.state == .live && conn.client !== first }
        XCTAssertTrue(again, "a fresh session on a fresh client")
        XCTAssertEqual(fixture.satellite.sessionPuts.count, 2)
    }

    /// A PC the person reaches for, with a pad bound to it, is the
    /// accessory's reconnecting until its session is up.
    func testReachingForAPCWithPadsBoundShowsAsReconnecting() async {
        fixture.prePair()
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        XCTAssertEqual(fixture.model.sessionFacts.session?.phase, .reconnecting)
        XCTAssertEqual(fixture.model.sessionFacts.session?.pcName, "Den PC")
        XCTAssertEqual(fixture.model.sessionFacts.session?.pads, 1)
        XCTAssertNil(fixture.model.sessionFacts.session?.latencyMs)
        let streaming = await fixture.waitUntil { self.fixture.model.sessionFacts.session?.phase == .streaming }
        XCTAssertTrue(streaming)
    }

    /// The foreground's silent sweep reaches for the same PC and shows no
    /// accessory: only the person's own reach does.
    func testASilentReconnectIsNotTheAccessorys() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        let settled = await fixture.waitUntil { self.fixture.model.reaching.state.isEmpty }
        XCTAssertTrue(settled, "the reach is forgotten once the link settled")
        fixture.model.enteredBackground()
        XCTAssertNil(fixture.model.sessionFacts.session)
        fixture.model.enteredForeground()
        XCTAssertEqual(fixture.network.wifi.get(fixture.serverId)?.state, .linking, "the sweep reaches for the PC")
        XCTAssertNil(fixture.model.sessionFacts.session, "a silent reach shows no accessory")
        let back = await fixture.waitUntil { self.fixture.model.sessionFacts.session?.phase == .streaming }
        XCTAssertTrue(back)
    }

    func testTheBackgroundClosesEverySessionAndTheForegroundReachesForThem() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.enteredBackground()
        XCTAssertNil(fixture.model.shellFacts.session)
        fixture.model.enteredForeground()
        let back = await fixture.waitUntil { self.fixture.model.shellFacts.session != nil }
        XCTAssertTrue(back)
    }

    func testEachLinkStateHasItsPhaseAndHealth() {
        XCTAssertEqual(sessionPhase(.connected), .streaming)
        XCTAssertEqual(sessionPhase(.unstable), .stoppedResponding)
        XCTAssertEqual(linkHealth(.connected), .online)
        XCTAssertEqual(linkHealth(.unstable), .lost, "a PC that stopped responding reads lost on its rows (D4)")
        XCTAssertEqual(linkHealth(.connecting), .connecting)
        XCTAssertEqual(linkHealth(.saved), .lost)
        XCTAssertTrue(sessionIsUp(.unstable))
        XCTAssertFalse(sessionIsUp(.connecting))
    }
}
