// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The low-power countdown through the model: armed exactly while the
/// screen is held (a session streaming with an active binding and Keep
/// screen on) and the dim is not up, at the delay Settings keeps, reset by
/// a touch, and rested by Never, the dim, a session that falters, a pad that
/// is unbound or away, Keep screen on turned off, or the session ending.
@MainActor
final class AppModelLowPowerTests: XCTestCase {

    private var fixture: SatelliteModelFixture!

    override func setUp() async throws {
        fixture = try SatelliteModelFixture(self)
    }

    override func tearDown() async throws {
        fixture?.tearDown()
        fixture = nil
    }

    private var model: AppModel {
        fixture.model
    }

    private var ticker: ManualTicker {
        fixture.lowPowerTicker
    }

    func testTheWatchArmsOnceASessionStreamsWithAPadBoundAndTheShellAllowsTheDim() async {
        model.setDimAllowed(true)
        XCTAssertFalse(ticker.running, "nothing streams yet")
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        XCTAssertFalse(ticker.running, "a session with no pad bound saves nothing")
        model.bind(slotId: "pad", to: fixture.serverId)
        let armed = await fixture.waitUntil { self.ticker.running }
        XCTAssertTrue(armed, "a pad streams, so the count runs")
        for _ in 0 ..< 15 {
            ticker.fire()
        }
        XCTAssertEqual(model.shellFacts.lowPower, LowPowerFact(countdown: 5, due: false), "Settings' default is twenty seconds")
        model.touched()
        XCTAssertEqual(model.shellFacts.lowPower, .idle)
        for _ in 0 ..< 20 {
            ticker.fire()
        }
        XCTAssertTrue(model.shellFacts.lowPower.due)
        model.lowPowerHandled()
        XCTAssertEqual(model.shellFacts.lowPower, .idle)
    }

    func testACoverNeverOrTheSessionEndingRestsTheWatch() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        model.setDimAllowed(true)
        XCTAssertTrue(ticker.running)
        model.setDimAllowed(false)
        XCTAssertFalse(ticker.running, "while the dim is up there is nothing to count")
        model.setDimAllowed(true)
        XCTAssertTrue(ticker.running)
        model.setDimAfter(.never)
        let rested = await fixture.waitUntil { !self.ticker.running }
        XCTAssertTrue(rested, "Never means never")
        model.setDimAfter(.tenSeconds)
        let armed = await fixture.waitUntil { self.ticker.running }
        XCTAssertTrue(armed)
        fixture.network.wifi.disconnect(id: fixture.serverId)
        let ended = await fixture.waitUntil { !self.ticker.running }
        XCTAssertTrue(ended, "no session, nothing to save power for")
    }

    /// A session that stopped responding, or whose pad let go, leaves the
    /// screen alone, so the person sees what is happening.
    func testAFalteringSessionOrAnUnboundPadRestsTheWatch() async throws {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        model.setDimAllowed(true)
        XCTAssertTrue(ticker.running)
        model.unbind(slotId: "pad")
        let unbound = await fixture.waitUntil { !self.ticker.running }
        XCTAssertTrue(unbound, "no pad streams")
        model.bind(slotId: "pad", to: fixture.serverId)
        let again = await fixture.waitUntil { self.ticker.running }
        XCTAssertTrue(again)
        let conn = try XCTUnwrap(fixture.network.wifi.get(fixture.serverId))
        try XCTUnwrap(conn.client).missedAcks.set(ProtocolConstants.heartbeatMissNotResponding)
        conn.aliveTick()
        let rested = await fixture.waitUntil { !self.ticker.running }
        XCTAssertTrue(rested, "a PC that stopped responding is something to see, not to dim")
    }

    /// A binding is remembered while its pad is away; it holds nothing then.
    func testAPadThatLeftRestsTheWatch() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        model.setDimAllowed(true)
        XCTAssertTrue(ticker.running)
        fixture.source.slots = []
        let rested = await fixture.waitUntil { !self.ticker.running }
        XCTAssertTrue(rested, "the binding stays, the pad is away")
        fixture.source.slots = [SatelliteModelFixture.pad]
        let armed = await fixture.waitUntil { self.ticker.running }
        XCTAssertTrue(armed, "the pad is back")
    }

    /// With Keep screen on off the phone locks on its own, so there is
    /// nothing to count down to.
    func testKeepScreenOnOffRestsTheWatch() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        model.bind(slotId: "pad", to: fixture.serverId)
        model.setDimAllowed(true)
        XCTAssertTrue(ticker.running)
        model.setKeepScreenOn(false)
        let rested = await fixture.waitUntil { !self.ticker.running }
        XCTAssertTrue(rested)
        model.setKeepScreenOn(true)
        let armed = await fixture.waitUntil { self.ticker.running }
        XCTAssertTrue(armed)
    }
}
