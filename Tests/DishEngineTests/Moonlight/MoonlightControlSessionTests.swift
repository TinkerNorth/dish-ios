// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore
@testable import DishEngine

/// The control stream over a fake transport with the test playing the host:
/// the handshake, every send sealed and framed, the replug's order, the
/// keepalive, the host's events opened and dispatched, forged packets
/// dropped, and the two ways the link ends.
final class MoonlightControlSessionTests: XCTestCase, PlaysMoonlightHost {

    let rikey = moonlightHex("edf04a215c4fbea20934120c8480d855")
    private let clock = AtomicInt(100_000)
    private var transport: FakeControlTransport!
    private let events = Locked<[MoonlightEvent]>([])
    private let closedCount = Locked(0)
    private var session: MoonlightControlSession!

    override func setUp() async throws {
        try await super.setUp()
        let transport = FakeControlTransport()
        let clock = clock
        let events = events
        let closedCount = closedCount
        self.transport = transport
        session = MoonlightControlSession(
            rikey: rikey,
            connectData: 0xFE88_1C39,
            transport: transport,
            now: { Int64(clock.get()) },
            random: { 7 },
            onEvent: { event in events.mutate { $0.append(event) } },
            onClosed: { closedCount.mutate { $0 += 1 } }
        )
    }

    private func connect() async -> Bool {
        let session: MoonlightControlSession = session
        let handshake = Task { await session.connect() }
        try? await Task.sleep(nanoseconds: 50_000_000)
        transport.onDatagram?(verifyConnect())
        return await handshake.value
    }

    // MARK: - Tests

    func testTheHandshakeConnectsOnVerifyConnect() async {
        XCTAssertEqual(session.state, .idle)
        let connected = await connect()
        XCTAssertTrue(connected)
        XCTAssertEqual(session.state, .connected)
        let sent = transport.takeSent()
        XCTAssertEqual(sent.first.map { Array($0.prefix(2)) }, [0x8F, 0xFF], "CONNECT to no peer yet")
        XCTAssertEqual(sent.first?.count, 4 + 48)
    }

    func testAHostThatNeverAnswersFailsTheHandshakeAtTheDeadline() async {
        clock.set(0)
        let session: MoonlightControlSession = session
        let handshake = Task { await session.connect() }
        try? await Task.sleep(nanoseconds: 150_000_000)
        clock.set(Int(MoonlightControlSession.handshakeTimeoutMs) + 1)
        let connected = await handshake.value
        XCTAssertFalse(connected)
        XCTAssertEqual(session.state, .closed)
        XCTAssertGreaterThanOrEqual(transport.takeSent().count, 1, "at least the CONNECT went out")
    }

    func testSendsAreSealedWithOneCounterAndFramedForChannelZero() async throws {
        _ = await connect()
        _ = transport.takeSent()
        session.sendControllerArrival(MoonlightInput.PadArrival(controller: 0, type: 2, capabilities: 0xFF, supportedButtons: 0x0010_F7FF))
        session.sendControllerState(MoonlightInput.PadFrame(controller: 0, activeMask: 1, buttons: MoonlightButton.buttonA))
        session.sendControllerBattery(controller: 0, state: MoonlightBatteryState.charging, percentage: 88)
        let sent = transport.takeSent()
        XCTAssertEqual(sent.count, 3)
        XCTAssertEqual(
            sent.map { Array($0[4 ..< 8]) },
            [[0x86, 0x00, 0x00, 0x01], [0x86, 0x00, 0x00, 0x02], [0x86, 0x00, 0x00, 0x03]],
            "reliable, channel 0, counted from 1"
        )
        XCTAssertEqual(
            sent.map { Array($0[10 ..< 14]) }.map { [$0[0], $0[1]] },
            [[0x01, 0x00], [0x01, 0x00], [0x01, 0x00]],
            "every payload is an encrypted control packet"
        )
        XCTAssertEqual(sent.map { Array($0[14 ..< 18]) }, [[0, 0, 0, 0], [1, 0, 0, 0], [2, 0, 0, 0]], "one sequence for the whole stream")
        XCTAssertEqual(
            try XCTUnwrap(plaintext(of: sent[0])),
            MoonlightInput.controllerArrival(.init(controller: 0, type: 2, capabilities: 0xFF, supportedButtons: 0x0010_F7FF))
        )
        XCTAssertEqual(try XCTUnwrap(plaintext(of: sent[2])), MoonlightInput.controllerBattery(controller: 0, state: 3, percentage: 88))
    }

    func testAReplugIsTheUnplugThenTheArrivalUnderOneHold() async throws {
        _ = await connect()
        _ = transport.takeSent()
        let arrival = MoonlightInput.PadArrival(controller: 1, type: 1, capabilities: 0x47, supportedButtons: 0xF7FF)
        session.sendControllerReplug(number: 1, otherPadsMask: 0b0101, arrival: arrival)
        let sent = transport.takeSent()
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(
            try XCTUnwrap(plaintext(of: sent[0])),
            MoonlightInput.controllerMulti(.init(controller: 1, activeMask: 0b0101)),
            "pad 1 named with its bit cleared"
        )
        XCTAssertEqual(try XCTUnwrap(plaintext(of: sent[1])), MoonlightInput.controllerArrival(arrival))
    }

    func testNothingIsSentOrSpentBeforeTheLinkIsUp() {
        session.sendControllerState(MoonlightInput.PadFrame(controller: 0, activeMask: 1))
        session.sendMouseMoveRel(deltaX: 1, deltaY: 1)
        XCTAssertEqual(transport.takeSent(), [], "dropped, not framed into the void")
    }

    func testTheKeepaliveGoesOutEveryHalfSecondOfTheClock() async {
        _ = await connect()
        _ = transport.takeSent()
        session.tick()
        XCTAssertEqual(transport.takeSent(), [], "just connected")
        clock.set(clock.get() + 500)
        session.tick()
        let pings = transport.takeSent().compactMap(plaintext(of:))
        XCTAssertEqual(pings, [MoonlightInput.periodicPing()])
        clock.set(clock.get() + 499)
        session.tick()
        XCTAssertEqual(transport.takeSent().compactMap(plaintext(of:)), [])
    }

    func testTheHostsEventsAreOpenedAndDispatchedAndForgeriesDropped() async {
        _ = await connect()
        _ = transport.takeSent()
        transport.onDatagram?(hostPacket(seq: 1, plaintext: moonlightHex("0b010a00000000000100341200ff"), hostSeq: 0))
        transport.onDatagram?(hostPacket(seq: 2, plaintext: moonlightHex("025505000000102030"), hostSeq: 1))
        var forged = hostPacket(seq: 3, plaintext: moonlightHex("0901040080030023"), hostSeq: 2)
        forged[forged.count - 1] ^= 0xFF
        transport.onDatagram?(forged)
        let seen: [MoonlightEvent] = events.get()
        XCTAssertEqual(
            seen,
            [.rumble(controller: 1, low: 0x1234, high: 0xFF00), .rgbLed(controller: 0, red: 0x10, green: 0x20, blue: 0x30)]
        )
        XCTAssertEqual(transport.takeSent().count, 3, "each host command acknowledged, the forged one included")
    }

    func testStopSendsTerminationThenDisconnectThenClosesTheSocket() async throws {
        _ = await connect()
        _ = transport.takeSent()
        session.stop()
        let sent = transport.takeSent()
        guard sent.count == 2 else { return XCTFail("TERMINATION then DISCONNECT, and \(sent.count) datagrams went out") }
        XCTAssertEqual(try XCTUnwrap(plaintext(of: sent[0])), MoonlightInput.termination())
        XCTAssertEqual(Array(sent[1][4 ..< 6]), [0x44, 0xFF], "the unsequenced DISCONNECT")
        XCTAssertTrue(transport.closed)
        XCTAssertEqual(session.state, .closed)
        session.sendControllerState(MoonlightInput.PadFrame(controller: 0, activeMask: 1))
        XCTAssertEqual(transport.takeSent(), [])
    }

    func testAPeerThatStopsAcknowledgingClosesTheLinkAndSaysSo() async {
        _ = await connect()
        session.sendControllerState(MoonlightInput.PadFrame(controller: 0, activeMask: 1))
        for _ in 0 ..< 40 where session.state == .connected {
            clock.set(clock.get() + 6000)
            session.tick()
        }
        XCTAssertEqual(session.state, .closed)
        XCTAssertEqual(closedCount.get(), 1)
        XCTAssertTrue(session.linkReport.hasPrefix("peer stopped acknowledging"))
    }
}
