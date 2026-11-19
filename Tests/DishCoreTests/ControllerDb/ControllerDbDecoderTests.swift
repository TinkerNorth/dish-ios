// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest

/// `controllers.json`, schema 1: a file of another schema is refused whole,
/// a record that does not decode is left out and the rest stand, and the
/// fields this reader does not know are ignored.
final class ControllerDbDecoderTests: XCTestCase {

    private func decoded(_ data: Data) throws -> ControllerDatabase {
        try decodeControllerDatabase(data).get()
    }

    func testARecordKeepsItsIdItsIdsItsFamilyItsStandingAndItsIssues() throws {
        let database = try decoded(ControllerDbFixtures.database([ControllerDbFixtures.tritonRecord]))
        let record = try XCTUnwrap(database.records.first)
        XCTAssertEqual(database.dbVersion, 1)
        XCTAssertEqual(record.id, "valve-steam-controller-2026-bluetooth")
        XCTAssertEqual(record.usb, [])
        XCTAssertEqual(record.bluetooth, ["28de:1303"], "an id is kept lowercase, as the index looks it up")
        XCTAssertEqual(record.family, "steamTriton")
        XCTAssertEqual(record.verification, .verified)
        XCTAssertEqual(record.issues.map(\.id), ["triton-ble-lag", "triton-usb-only"])
        XCTAssertEqual(record.issues.first?.transport, .bluetooth)
        XCTAssertEqual(record.issues.last?.transport, .usb)
    }

    func testTheReservedAndUnknownFieldsAreIgnored() throws {
        let database = try decoded(ControllerDbFixtures.database([ControllerDbFixtures.tritonRecord]))
        XCTAssertEqual(database.records.count, 1, "lifecycle and input.protocol.fields do not refuse the record")
    }

    func testARecordWithNoIdentityOrIssuesReadsAsEmpty() throws {
        let bare = """
        { "id": "bare", "input": { "protocol": { "ref": "hid" } }, "support": { "verification": { "state": "guessed" } } }
        """
        let record = try XCTUnwrap(decoded(ControllerDbFixtures.database([bare])).records.first)
        XCTAssertEqual(record.usb, [])
        XCTAssertEqual(record.bluetooth, [])
        XCTAssertEqual(record.issues, [])
        XCTAssertEqual(record.verification, .guessed)
    }

    func testAFileOfAnotherSchemaIsRefused() {
        let data = ControllerDbFixtures.database([ControllerDbFixtures.tritonRecord], schema: 2)
        XCTAssertEqual(decodeControllerDatabase(data), .failure(.unsupportedSchema))
    }

    func testAFileWithNoSchemaIsRefused() {
        let data = Data(#"{ "dbVersion": 1, "records": [] }"#.utf8)
        XCTAssertEqual(decodeControllerDatabase(data), .failure(.unsupportedSchema))
    }

    func testAFileThatIsNotJsonIsRefused() {
        XCTAssertEqual(decodeControllerDatabase(Data("not json".utf8)), .failure(.badJson))
    }

    func testAFileWithNoRecordsOrNoVersionIsRefused() {
        XCTAssertEqual(decodeControllerDatabase(Data(#"{ "schema": 1, "dbVersion": 1 }"#.utf8)), .failure(.badJson))
        XCTAssertEqual(decodeControllerDatabase(Data(#"{ "schema": 1, "records": [] }"#.utf8)), .failure(.badJson))
    }

    func testARecordWithoutAnIdIsLeftOutAndTheRestStand() throws {
        let noId = #"{ "input": { "protocol": { "ref": "hid" } }, "support": { "verification": { "state": "verified" } } }"#
        let database = try decoded(ControllerDbFixtures.database([noId, ControllerDbFixtures.dualSenseRecord]))
        XCTAssertEqual(database.records.map(\.id), ["sony-dualsense"])
    }

    func testARecordWithAnEmptyIdIsLeftOut() throws {
        let empty = #"{ "id": "", "input": { "protocol": { "ref": "hid" } }, "support": { "verification": { "state": "verified" } } }"#
        XCTAssertEqual(try decoded(ControllerDbFixtures.database([empty])).records, [])
    }

    func testARecordOfAnotherSchemaIsLeftOut() throws {
        let later = """
        { "schema": 2, "id": "later", "input": { "protocol": { "ref": "hid" } }, "support": { "verification": { "state": "verified" } } }
        """
        XCTAssertEqual(try decoded(ControllerDbFixtures.database([later])).records, [])
    }

    func testARecordWithAStandingThisSchemaDoesNotNameIsLeftOut() throws {
        let odd = #"{ "id": "odd", "input": { "protocol": { "ref": "hid" } }, "support": { "verification": { "state": "rumoured" } } }"#
        XCTAssertEqual(try decoded(ControllerDbFixtures.database([odd])).records, [])
    }

    func testARecordWithNoFamilyIsLeftOut() throws {
        let noFamily = #"{ "id": "nofamily", "input": {}, "support": { "verification": { "state": "verified" } } }"#
        XCTAssertEqual(try decoded(ControllerDbFixtures.database([noFamily])).records, [])
    }

    func testAnIssueOnATransportThisSchemaDoesNotNameIsOnEveryTransport() throws {
        let record = """
        { "id": "pad", "input": { "protocol": { "ref": "hid" } },
          "support": { "verification": { "state": "verified" },
                       "issues": [{ "id": "a", "transport": "infrared", "device": "AYN Thor", "os": { "android": 15 } }] } }
        """
        let issue = try XCTUnwrap(decoded(ControllerDbFixtures.database([record])).records.first?.issues.first)
        XCTAssertNil(issue.transport)
        XCTAssertEqual(issue.device, "AYN Thor")
        XCTAssertEqual(issue.os, ["android": 15])
    }

    func testAnIssuesStatusSaysWhetherItIsOpen() throws {
        let record = """
        { "id": "pad", "input": { "protocol": { "ref": "hid" } },
          "support": { "verification": { "state": "verified" },
                       "issues": [{ "id": "a", "status": "open" }, { "id": "b", "status": "fixed" }, { "id": "c" }] } }
        """
        let issues = try XCTUnwrap(decoded(ControllerDbFixtures.database([record])).records.first?.issues)
        XCTAssertEqual(issues.map(\.open), [true, false, false])
    }

    func testAnOsVersionIsANumberOrAVersionString() throws {
        let record = """
        { "id": "pad", "input": { "protocol": { "ref": "hid" } },
          "support": { "verification": { "state": "verified" },
                       "issues": [{ "id": "a", "os": { "ios": "26.1", "android": 15, "macos": "Tahoe" } }] } }
        """
        let issue = try XCTUnwrap(decoded(ControllerDbFixtures.database([record])).records.first?.issues.first)
        XCTAssertEqual(issue.os, ["ios": 26, "android": 15, "macos": -1])
    }

    func testTheBundledFileHoldsEveryRecordOfDbVersionOne() throws {
        let data = try XCTUnwrap(BundledControllerDb.files()[ControllerDbFiles.controllers])
        let database = try decoded(data)
        XCTAssertEqual(database.dbVersion, 1)
        XCTAssertEqual(database.records.count, 272)
    }
}
