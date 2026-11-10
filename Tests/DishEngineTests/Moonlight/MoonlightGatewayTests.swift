// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Security
import XCTest
@testable import DishEngine

/// The pin rules around mutual TLS: first use pins, the same leaf matches,
/// another leaf is refused and the pin kept, phase 5 trusts one certificate
/// whatever is pinned, and two records of one host fold their pins. The
/// pins are the app's own `CertPins`, kept in memory here.
final class MoonlightGatewayTests: XCTestCase {

    private var server: MoonlightLoopbackServer!
    private var pins: CertPins!
    private var hostIdentity: MoonlightIdentityStore!
    private var gateway: MoonlightGateway!
    private let hostId = "moonlight:127.0.0.1"

    override func setUp() async throws {
        try await super.setUp()
        server = MoonlightLoopbackServer()
        pins = CertPins(file: nil)
        hostIdentity = try XCTUnwrap(MoonlightIdentityFixtures.host())
        let hostSecIdentity = try XCTUnwrap(hostIdentity.secIdentity())
        let client = try XCTUnwrap(MoonlightIdentityFixtures.client())
        gateway = MoonlightGateway(identity: client, pins: pins)
        server.answer("/serverinfo", status: 200, body: "<root><PairStatus>1</PairStatus></root>")
        _ = try server.start(identity: hostSecIdentity, requireClientCertificate: true)
    }

    override func tearDown() async throws {
        server.stop()
        try await super.tearDown()
    }

    private func serverInfo() -> MoonlightHttpRequest {
        MoonlightHttpRequest(host: "127.0.0.1", port: server.port, tls: true, pathAndQuery: "/serverinfo")
    }

    func testFirstUsePinsAndTheSameLeafMatches() async {
        XCTAssertNil(pins.certPin(host: hostId))
        let first = await gateway.getSecure(serverInfo(), hostId: hostId)
        XCTAssertEqual(first.status, 200)
        XCTAssertEqual(pins.certPin(host: hostId), hostIdentity.fingerprintHex, "pinned on first use")
        XCTAssertEqual(gateway.pinnedFingerprint(hostId: hostId), hostIdentity.fingerprintHex)
        let second = await gateway.getSecure(serverInfo(), hostId: hostId)
        XCTAssertEqual(second.status, 200)
        XCTAssertEqual(server.clientCertificates.count, 2, "the dish's certificate every time")
    }

    func testAnotherLeafIsRefusedAndThePinKept() async {
        pins.setCertPin(host: hostId, fingerprintHex: "00" + String(repeating: "ab", count: 31))
        let reply = await gateway.getSecure(serverInfo(), hostId: hostId)
        XCTAssertEqual(reply, .unreachable)
        XCTAssertEqual(pins.certPin(host: hostId), "00" + String(repeating: "ab", count: 31), "kept, never overwritten by an imposter")
        XCTAssertEqual(server.requests, [], "the handshake never completed")
        gateway.forgetPin(hostId: hostId)
        XCTAssertNil(pins.certPin(host: hostId))
        let again = await gateway.getSecure(serverInfo(), hostId: hostId)
        XCTAssertEqual(again.status, 200, "first use again")
    }

    func testPhaseFiveTrustsTheProvenCertificateAlone() async {
        pins.setCertPin(host: hostId, fingerprintHex: "stale-pin-of-a-rebuilt-host")
        let proven = await gateway.getSecureTrusting(serverInfo(), certificateDER: hostIdentity.certificateDER)
        XCTAssertEqual(proven.status, 200, "whatever is pinned")
        XCTAssertEqual(pins.certPin(host: hostId), "stale-pin-of-a-rebuilt-host", "and it pins nothing itself")
        let other = await gateway.getSecureTrusting(serverInfo(), certificateDER: Data([0x30, 0x00]))
        XCTAssertEqual(other, .unreachable)
        gateway.pinProven(hostId: hostId, certificateDER: hostIdentity.certificateDER)
        XCTAssertEqual(pins.certPin(host: hostId), hostIdentity.fingerprintHex, "a pairing's certificate outranks the stale pin")
    }

    func testFoldingTwoRecordsPins() {
        pins.setCertPin(host: "moonlight:old", fingerprintHex: "aa")
        XCTAssertTrue(gateway.foldPins(from: "moonlight:old", to: "moonlight:new", trusted: "moonlight:old"), "one pin moves")
        XCTAssertEqual(pins.certPin(host: "moonlight:new"), "aa")
        XCTAssertNil(pins.certPin(host: "moonlight:old"))
        pins.setCertPin(host: "moonlight:a", fingerprintHex: "aa")
        pins.setCertPin(host: "moonlight:b", fingerprintHex: "bb")
        XCTAssertFalse(
            gateway.foldPins(from: "moonlight:a", to: "moonlight:b", trusted: "moonlight:b"),
            "two pins that disagree are two machines"
        )
        XCTAssertNil(pins.certPin(host: "moonlight:a"))
        XCTAssertNil(pins.certPin(host: "moonlight:b"), "neither is kept")
        pins.setCertPin(host: "moonlight:c", fingerprintHex: "cc")
        pins.setCertPin(host: "moonlight:d", fingerprintHex: "cc")
        XCTAssertTrue(gateway.foldPins(from: "moonlight:c", to: "moonlight:d", trusted: "moonlight:d"))
        XCTAssertEqual(pins.certPin(host: "moonlight:d"), "cc")
    }

    func testWithoutAnIdentityMutualTlsPresentsNothingAndAPlainCallStillGoes() async throws {
        let bare = MoonlightGateway(identity: nil, pins: pins)
        let refused = await bare.getSecure(serverInfo(), hostId: hostId)
        XCTAssertEqual(refused, .unreachable, "a host that requires the dish's certificate gets none")
        let plain = MoonlightLoopbackServer()
        plain.answer("/serverinfo", status: 200, body: "<root/>")
        let port = try plain.start()
        defer { plain.stop() }
        let answered = await bare.getPlain(
            MoonlightHttpRequest(host: "127.0.0.1", port: port, tls: false, pathAndQuery: "/serverinfo"),
            timeout: 5
        )
        XCTAssertEqual(answered.status, 200)
    }
}
