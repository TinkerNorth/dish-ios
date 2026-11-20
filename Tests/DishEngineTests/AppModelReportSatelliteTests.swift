// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// A report's hosts from both ends, against a fake satellite on the
/// loopback: a satellite that answers its diagnostics route rides the file
/// whole; one older than the route by its capabilities is never asked; one
/// that does not know the connection, refuses the proof, is too slow or has
/// no session leaves the client's own copy and the reason; and every live
/// link carries the client's own view of the session.
@MainActor
final class AppModelReportSatelliteTests: XCTestCase {

    private static let document = #"{"format":"satellite-connection-diagnostics.v1","satellite":{"version":"2.3.0"}}"#

    private var fixture: SatelliteModelFixture!

    override func setUp() async throws {
        try await super.setUp()
        fixture = try SatelliteModelFixture(self)
        fixture.satellite.serverVersion = "2.3.0"
    }

    override func tearDown() async throws {
        fixture?.tearDown()
        fixture = nil
        try await super.tearDown()
    }

    private static let draft = ReportDraft(category: .connection, text: "It drops every minute.", controllerId: "pad")

    /// The first host of the file the model prepared.
    private func preparedHost() async throws -> [String: Any] {
        await fixture.model.previewReport(Self.draft).value
        let text = try XCTUnwrap(preparedText(fixture.model.reportFacts.preparation), "no file was prepared")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        return try XCTUnwrap((object["hosts"] as? [[String: Any]])?.first)
    }

    private func connectAndBind() async throws {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        let applied = await fixture.waitUntil { self.fixture.model.bindingProgress == .done }
        XCTAssertTrue(applied)
    }

    // MARK: - What the host says of itself

    func testASatelliteThatAnswersRidesTheFileWhole() async throws {
        fixture.satellite.diagnosticsRoute = .answer(Self.document)
        try await connectAndBind()
        let host = try await preparedHost()
        let snapshot = try XCTUnwrap(host["snapshot"] as? [String: Any])
        XCTAssertEqual(snapshot["format"] as? String, "satellite-connection-diagnostics.v1")
        XCTAssertEqual((snapshot["satellite"] as? [String: Any])?["version"] as? String, "2.3.0")
        XCTAssertTrue(host["snapshotError"] is NSNull)
        XCTAssertEqual(fixture.satellite.diagnosticsGets, 1, "asked once, with the pairing's proof")
        XCTAssertEqual(host["version"] as? String, "2.3.0", "the version the capabilities told")
    }

    func testASatelliteOlderThanTheRouteIsNeverAskedAndLeavesItsCapabilities() async throws {
        fixture.satellite.serverVersion = "2.2.0"
        try await connectAndBind()
        let host = try await preparedHost()
        XCTAssertEqual(host["snapshotError"] as? String, "olderSatellite")
        let snapshot = try XCTUnwrap(host["snapshot"] as? [String: Any])
        XCTAssertEqual(snapshot["format"] as? String, "satellite-capabilities")
        XCTAssertEqual(snapshot["serverVersion"] as? String, "2.2.0")
        XCTAssertEqual(snapshot["protocol"] as? [Int], [1, 4])
        XCTAssertEqual(fixture.satellite.diagnosticsGets, 0, "an older satellite is not asked")
    }

    func testANotFoundFromASatelliteThatServesTheRouteIsAnUnknownConnection() async throws {
        fixture.satellite.diagnosticsRoute = .unknownConnection
        try await connectAndBind()
        let host = try await preparedHost()
        XCTAssertEqual(host["snapshotError"] as? String, "unknownConnection")
        XCTAssertEqual((host["snapshot"] as? [String: Any])?["format"] as? String, "satellite-capabilities")
    }

    func testASatelliteThatRefusesTheProofIsUnauthorized() async throws {
        fixture.satellite.diagnosticsRoute = .answer(Self.document)
        try await connectAndBind()
        fixture.satellite.forced401Code = "BAD_PROOF"
        let host = try await preparedHost()
        XCTAssertEqual(host["snapshotError"] as? String, "unauthorized")
        XCTAssertEqual((host["snapshot"] as? [String: Any])?["format"] as? String, "satellite-capabilities")
    }

    func testASatelliteTooSlowToAnswerIsATimeout() async throws {
        fixture.satellite.diagnosticsRoute = .slow(Self.document, seconds: 1.5)
        fixture.network.wifi.snapshotTimeoutSeconds = 0.3
        try await connectAndBind()
        let host = try await preparedHost()
        XCTAssertEqual(host["snapshotError"] as? String, "timeout")
        XCTAssertEqual((host["snapshot"] as? [String: Any])?["format"] as? String, "satellite-capabilities")
    }

    func testASatelliteWithNoSessionIsNotAskedAndReadsOffline() async throws {
        fixture.satellite.diagnosticsRoute = .answer(Self.document)
        fixture.prePair()
        fixture.model.pageAppeared(.diagnostics)
        let host = try await preparedHost()
        XCTAssertEqual(host["snapshotError"] as? String, "offline")
        XCTAssertTrue(host["session"] is NSNull, "no session, no view of one")
        XCTAssertEqual(fixture.satellite.diagnosticsGets, 0)
    }

    // MARK: - The client's own view

    func testALiveLinkCarriesItsSlotsAckRoundTripsAndCountsByKind() async throws {
        try await connectAndBind()
        let acked = await fixture
            .waitUntil(timeout: 8) { self.fixture.network.wifi.get(self.fixture.serverId)?.lastHeartbeatAck?.bitmap == 1 }
        XCTAssertTrue(acked, "an enriched ack came back naming the bound pad")
        let host = try await preparedHost()
        let session = try XCTUnwrap(host["session"] as? [String: Any])
        let slot = try XCTUnwrap((session["slots"] as? [[String: Any]])?.first)
        XCTAssertEqual(slot["index"] as? Int, 0)
        XCTAssertEqual(slot["result"] as? String, "ok")
        XCTAssertEqual(slot["backend"] as? String, "fake")
        let requested = try XCTUnwrap(slot["requestedType"] as? String)
        XCTAssertFalse(requested.isEmpty, "the catalog's slug, or the number as text")
        XCTAssertEqual(slot["appliedType"] as? String, requested)
        XCTAssertNotNil(slot["touchpadMode"] as? String)
        let ack = try XCTUnwrap(session["ack"] as? [String: Any])
        XCTAssertEqual(ack["activeBitmap"] as? String, "0001")
        let sent = try XCTUnwrap(session["sent"] as? [String: Any])
        XCTAssertGreaterThan(sent["heartbeat"] as? Int ?? 0, 0, "the heartbeat left at once")
        XCTAssertEqual(sent["mic"] as? Int, 0, "iOS sends no microphone audio")
        let received = try XCTUnwrap(session["received"] as? [String: Any])
        XCTAssertGreaterThan(received["heartbeatAck"] as? Int ?? 0, 0, "its ack came back")
        XCTAssertNotNil(session["rtt"] as? [String: Any])
    }

    func testTheFileHoldsNoHostsNameAndNoAddress() async throws {
        fixture.satellite.diagnosticsRoute = .answer(Self.document)
        try await connectAndBind()
        await fixture.model.previewReport(Self.draft).value
        let text = try XCTUnwrap(preparedText(fixture.model.reportFacts.preparation), "no file was prepared")
        for secret in ["Den PC", "127.0.0.1", fixture.satellite.machineId] {
            XCTAssertFalse(text.contains(secret), "the file holds \(secret)")
        }
    }
}

/// The prepared file's text, nil in any other state.
private func preparedText(_ preparation: ReportPreparation) -> String? {
    guard case let .ready(_, prepared) = preparation else { return nil }
    return prepared.text
}
