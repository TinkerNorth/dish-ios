// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// Pairing through the model, both paths at once: the card opens on the
/// operator request with a fresh client PIN, the operator's approval or the
/// typed PIN lands the key and opens the session, the card closes when the
/// session takes over, and a wrong PIN, a cancel and a new code each leave
/// the card as it should read.
@MainActor
final class AppModelPairingTests: XCTestCase {

    private var fixture: SatelliteModelFixture!

    override func setUp() async throws {
        fixture = try SatelliteModelFixture(self)
        fixture.satellite.pairingKeyHex = nil
        let scanned = await fixture.scan()
        XCTAssertTrue(scanned, "the satellite was heard, as a row's Pair needs")
    }

    override func tearDown() async throws {
        fixture?.tearDown()
        fixture = nil
    }

    private var model: AppModel {
        fixture.model
    }

    func testBeginPairingOpensTheCardOnAFreshOperatorRequest() async throws {
        model.beginPairing(serverId: fixture.serverId)
        let card = try XCTUnwrap(model.openPairing)
        XCTAssertEqual(card.server.id, fixture.serverId)
        XCTAssertEqual(card.attempt.phase, .awaiting)
        XCTAssertEqual(card.attempt.clientPin.count, 4)
        XCTAssertTrue(card.attempt.clientPin.allSatisfy(\.isNumber))
        let filed = await fixture.waitUntil { self.fixture.satellite.lastClientPin == card.attempt.clientPin }
        XCTAssertTrue(filed, "the satellite holds the request with the card's PIN")
    }

    func testTheOperatorsApprovalOpensTheSessionAndClosesTheCard() async {
        model.beginPairing(serverId: fixture.serverId)
        let filed = await fixture.waitUntil { self.fixture.satellite.lastClientPin != nil }
        XCTAssertTrue(filed)
        fixture.satellite.approveClientPin()
        let live = await fixture.waitUntil { self.fixture.network.wifi.get(self.fixture.serverId)?.state == .live }
        XCTAssertTrue(live)
        let closed = await fixture.waitUntil { self.model.openPairing == nil }
        XCTAssertTrue(closed, "the session took over from the card")
        XCTAssertEqual(model.shellFacts.paired.map(\.id), [fixture.serverId])
    }

    func testATypedPinPairsAndStopsTheOperatorRequest() async {
        model.beginPairing(serverId: fixture.serverId)
        model.submitPin(fixture.serverId, pin: fixture.satellite.operatorPin)
        let live = await fixture.waitUntil { self.fixture.network.wifi.get(self.fixture.serverId)?.state == .live }
        XCTAssertTrue(live)
        XCTAssertNil(model.openPairing)
        XCTAssertNotNil(fixture.keyStore.pairingKeyHex(for: fixture.serverId))
    }

    func testAWrongPinIsRejectedOnTheCardAndTheRequestStands() async {
        model.beginPairing(serverId: fixture.serverId)
        model.submitPin(fixture.serverId, pin: "0000")
        let rejected = await fixture.waitUntil { self.model.openPairing?.attempt.rejection == .wrongPin }
        XCTAssertTrue(rejected)
        XCTAssertEqual(model.openPairing?.attempt.rejections, 1)
        XCTAssertEqual(model.openPairing?.attempt.phase, .awaiting, "the operator request still runs beside it")
    }

    func testCancelClosesTheCardAndStopsThePoll() {
        model.beginPairing(serverId: fixture.serverId)
        model.cancelPairing(fixture.serverId)
        XCTAssertNil(model.openPairing)
        XCTAssertNil(model.pairingAttempts[fixture.serverId])
        XCTAssertNil(model.pairingTarget)
    }

    func testANewCodeFilesAFreshRequest() async {
        model.beginPairing(serverId: fixture.serverId)
        model.newCode(fixture.serverId)
        XCTAssertEqual(model.openPairing?.attempt.phase, .awaiting)
        let fresh = model.openPairing?.attempt.clientPin
        let filed = await fixture.waitUntil { fresh != nil && self.fixture.satellite.lastClientPin == fresh }
        XCTAssertTrue(filed, "the satellite holds the new code")
    }

    func testAConnectWithoutAKeyOpensTheCard() async {
        model.connect(fixture.serverId)
        let opened = await fixture.waitUntil { self.model.openPairing != nil }
        XCTAssertTrue(opened, "a reachable satellite with no key asks for a PIN")
        XCTAssertEqual(model.lastConnectionEvent, .pairingRequired(fixture.server))
    }

    /// Rename this iPhone: the name the satellite sees changes, and the
    /// request is filed again so the operator reads the new name.
    func testRenamingThisIPhoneFilesAFreshRequestUnderTheNewName() async throws {
        model.beginPairing(serverId: fixture.serverId)
        let before = try XCTUnwrap(model.openPairing?.attempt.clientPin)
        let filed = await fixture.waitUntil { self.fixture.satellite.lastClientPin == before }
        XCTAssertTrue(filed)
        model.renameThisIPhone(fixture.serverId, to: "Den iPhone")
        XCTAssertEqual(model.shellFacts.preferences.deviceName, "Den iPhone")
        let fresh = try XCTUnwrap(model.openPairing?.attempt.clientPin)
        XCTAssertNotEqual(fresh, before, "a new code carries the new name")
        let refiled = await fixture.waitUntil { self.fixture.satellite.lastClientPin == fresh }
        XCTAssertTrue(refiled)
    }
}
