// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest

/// What a host says of itself in the support file: the route's answer read
/// into a document or a reason, the client's own copy beside the reason,
/// and a Moonlight host's serverinfo without its name.
final class HostSnapshotTests: XCTestCase {

    private static let document = Data(#"{"format":"satellite-connection-diagnostics.v1","satellite":{"version":"2.3.0"}}"#.utf8)

    /// What a satellite older than the route told in its capabilities.
    private static let capabilities = facts(version: "2.2.0")

    /// What a satellite that serves the route told.
    private static let current = facts(version: "2.3.0")

    private static func facts(version: String) -> SatelliteCapabilitiesFacts {
        SatelliteCapabilitiesFacts(
            serverVersion: version,
            protocolVersion: 4,
            backends: [
                CapabilityBackendFact(
                    id: "hidmaestro",
                    available: true,
                    errorCode: nil,
                    lifecycle: "supported",
                    driverVersion: "2.1.0.1716",
                    bundledVersion: "2.1.0.1716",
                    versionState: "current",
                    audio: false
                )
            ],
            controllerAudio: CapabilityAudioFact(enabled: true, mic: false, speaker: true, hapticAudio: false),
            catalogVersion: 2
        )
    }

    // MARK: - The route's answer

    func testASuccessWithOneObjectIsTheSnapshotWhole() {
        let outcome = snapshotOutcome(.answered(status: 200, body: Self.document))
        guard case let .snapshot(document) = outcome else { return XCTFail("expected a snapshot, got \(outcome)") }
        XCTAssertEqual(document["format"]?.string, "satellite-connection-diagnostics.v1")
        XCTAssertEqual(document["satellite"]?["version"]?.string, "2.3.0")
    }

    func testASuccessWhoseBodyIsNotAnObjectIsABadReply() {
        XCTAssertEqual(snapshotOutcome(.answered(status: 200, body: Data("[1,2]".utf8))), .failed(.badReply))
        XCTAssertEqual(snapshotOutcome(.answered(status: 200, body: Data("not json".utf8))), .failed(.badReply))
    }

    func testANotFoundFromASatelliteThatServesTheRouteIsAnUnknownConnection() {
        XCTAssertEqual(snapshotOutcome(.answered(status: 404, body: Data())), .failed(.unknownConnection))
    }

    // MARK: - Who is asked

    func testASatelliteBelowTwoThreeIsNeverAsked() {
        for version in ["2.2.9", "1.6.0", "2.2", "0.9.0-beta"] {
            XCTAssertFalse(asksForConnectionDiagnostics(Self.facts(version: version)), version)
        }
    }

    func testASatelliteOfTwoThreeOrLaterIsAsked() {
        for version in ["2.3.0", "2.3", "2.10.0", "3.0", "2.3.0-rc1"] {
            XCTAssertTrue(asksForConnectionDiagnostics(Self.facts(version: version)), version)
        }
    }

    func testASatelliteWhoseVersionIsUnknownIsAskedAndItsAnswerDecides() {
        XCTAssertTrue(asksForConnectionDiagnostics(nil))
        XCTAssertTrue(asksForConnectionDiagnostics(Self.facts(version: "")))
    }

    func testARefusedProofIsUnauthorized() {
        XCTAssertEqual(snapshotOutcome(.answered(status: 401, body: Data())), .failed(.unauthorized))
        XCTAssertEqual(snapshotOutcome(.answered(status: 403, body: Data())), .failed(.unauthorized))
    }

    func testAServerErrorIsABadReply() {
        XCTAssertEqual(snapshotOutcome(.answered(status: 500, body: Data("{}".utf8))), .failed(.badReply))
    }

    func testNoAnswerInTimeIsATimeout() {
        XCTAssertEqual(snapshotOutcome(.timedOut), .failed(.timeout))
    }

    func testNoAnswerAtAllIsOffline() {
        XCTAssertEqual(snapshotOutcome(.unreachable), .failed(.offline))
    }

    func testTheWaitIsTwoSeconds() {
        XCTAssertEqual(HostSnapshotPolicy.timeoutSeconds, 2)
    }

    // MARK: - A satellite's entry

    func testAnAnsweringSatelliteCarriesItsDocumentAndNoError() {
        let document = JSONValue.object(["format": .string("satellite-connection-diagnostics.v1")])
        let entry = satelliteSnapshot(.snapshot(document), cached: Self.current)
        XCTAssertEqual(entry, BundleHostSnapshot(snapshot: document, error: nil))
    }

    func testAnOlderSatelliteCarriesTheCapabilitiesAlreadyFetched() {
        let entry = satelliteSnapshot(nil, cached: Self.capabilities)
        XCTAssertEqual(entry.error, .olderSatellite)
        XCTAssertEqual(entry.snapshot?["format"]?.string, "satellite-capabilities")
        XCTAssertEqual(entry.snapshot?["serverVersion"]?.string, "2.2.0")
    }

    func testEveryFailureKeepsTheCachedCopyBesideItsReason() {
        for error in [SnapshotError.offline, .unauthorized, .timeout, .unknownConnection, .badReply] {
            let entry = satelliteSnapshot(.failed(error), cached: Self.current)
            XCTAssertEqual(entry.error, error)
            XCTAssertEqual(entry.snapshot?["format"]?.string, "satellite-capabilities")
        }
    }

    func testAFailureWithNothingCachedCarriesTheReasonAlone() {
        XCTAssertEqual(satelliteSnapshot(.failed(.timeout), cached: nil), BundleHostSnapshot(snapshot: nil, error: .timeout))
    }

    func testASatelliteWithNoLiveLinkWasNotAskedAndReadsOffline() {
        let entry = satelliteSnapshot(nil, cached: Self.current)
        XCTAssertEqual(entry.error, .offline)
        XCTAssertEqual(entry.snapshot?["format"]?.string, "satellite-capabilities")
    }

    // MARK: - The client's own copies

    func testTheCapabilitiesCopyIsShapedAsTheContractSays() {
        let document = satelliteCapabilitiesDocument(Self.capabilities)
        XCTAssertEqual(document["protocol"], .array([.number(1), .number(4)]))
        XCTAssertEqual(document["catalogVersion"], .number(2))
        XCTAssertEqual(document["controllerAudio"]?["speaker"], .bool(true))
        guard case let .array(backends)? = document["backends"] else { return XCTFail("backends is a list") }
        XCTAssertEqual(backends.first?["id"]?.string, "hidmaestro")
        XCTAssertEqual(backends.first?["driverVersion"]?.string, "2.1.0.1716")
    }

    func testWhatAnOlderSatelliteLeftOutIsNull() {
        let bare = SatelliteCapabilitiesFacts(
            serverVersion: "",
            protocolVersion: 1,
            backends: [],
            controllerAudio: nil,
            catalogVersion: nil
        )
        let document = satelliteCapabilitiesDocument(bare)
        XCTAssertEqual(document["serverVersion"], .null)
        XCTAssertEqual(document["controllerAudio"], .null)
        XCTAssertEqual(document["catalogVersion"], .null)
    }

    func testAMoonlightHostCarriesItsVersionAloneAndNeverItsName() throws {
        let xml = "<root status_code=\"200\"><hostname>Gaming Rig</hostname><uniqueid>UNIQUE-1234</uniqueid>"
            + "<PairStatus>1</PairStatus><currentgame>7</currentgame><state>SUNSHINE_SERVER_BUSY</state>"
            + "<mac>aa:bb:cc:dd:ee:ff</mac><LocalIP>192.168.1.40</LocalIP><appversion>7.1.431.-1</appversion></root>"
        let info = try XCTUnwrap(MoonlightXml.serverInfo(xml))
        let entry = moonlightSnapshot(info)
        XCTAssertNil(entry.error)
        let document = try XCTUnwrap(entry.snapshot)
        XCTAssertEqual(document["format"]?.string, "moonlight-serverinfo")
        XCTAssertEqual(document["appVersion"]?.string, "7.1.431.-1")
        XCTAssertEqual(document["state"], .null, "the plaintext serverinfo reports every host free")
        XCTAssertEqual(document["pairStatus"], .null, "and every caller unpaired")
        let text = try XCTUnwrap(String(bytes: JSONEncoder().encode(document), encoding: .utf8))
        for secret in ["Gaming Rig", "UNIQUE-1234", "aa:bb:cc", "192.168.1.40"] {
            XCTAssertFalse(text.contains(secret), "the snapshot holds \(secret)")
        }
    }

    func testAMoonlightHostNeverReadIsOffline() {
        XCTAssertEqual(moonlightSnapshot(nil), BundleHostSnapshot(snapshot: nil, error: .offline))
    }

    // MARK: - The host's own words

    func testTheHostsLabelAndAddressReadAsItsAliasInKeysAndValues() {
        let document = JSONValue.object([
            "satellite": .object(["machine": .string("Den PC on 192.168.1.24")]),
            "clients": .object(["Den PC": .array([.string("192.168.1.24:9443"), .number(4), .null])])
        ])
        let scrubbed = scrubbedSnapshot(document, naming: ["Den PC", "192.168.1.24"], alias: "Host 1")
        XCTAssertEqual(scrubbed, .object([
            "satellite": .object(["machine": .string("Host 1 on Host 1")]),
            "clients": .object(["Host 1": .array([.string("Host 1:9443"), .number(4), .null])])
        ]))
    }

    func testAnEmptyLabelLeavesTheDocumentAlone() {
        let document = JSONValue.object(["a": .string("b")])
        XCTAssertEqual(scrubbedSnapshot(document, naming: ["", ""], alias: "Host 1"), document)
    }

    func testANameInsideALongerOneIsReplacedWhole() {
        let scrubbed = scrubbedSnapshot(.string("Den PC 2"), naming: ["Den", "Den PC 2"], alias: "Host 1")
        XCTAssertEqual(scrubbed, .string("Host 1"))
    }

    // MARK: - A slot's type

    func testASlotsTypeIsTheCatalogsSlugOrTheNumberAsText() {
        XCTAssertEqual(slotTypeWord(2, slugs: [2: "dualsense"]), "dualsense")
        XCTAssertEqual(slotTypeWord(2, slugs: [:]), "2")
        XCTAssertEqual(slotTypeWord(2, slugs: [2: ""]), "2")
    }
}
