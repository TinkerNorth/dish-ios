// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest

/// `dish-diagnostics.v1` as the fleet's contract shapes it: the envelope,
/// a null where nothing is known rather than a missing key, the file's
/// name, and the mail's address and subject.
final class DiagnosticsBundleTests: XCTestCase {

    private static let createdAtMs: Int64 = 1_795_122_251_000

    private static let steamPad = BundleController(
        record: "valve-steam-controller-2026-bluetooth",
        verification: "verified",
        transport: .bluetooth,
        path: .bluetooth,
        hardware: BundleHardware(vid: "28de", pid: "1303", product: "Valve Steam Controller (2026, Bluetooth)", category: nil)
    )

    private static let unknownPad = BundleController(
        record: nil,
        verification: nil,
        transport: .bluetooth,
        path: .gameController,
        hardware: BundleHardware(vid: nil, pid: nil, product: "Xbox Wireless Controller", category: "Xbox One")
    )

    private static let bundle = DiagnosticsBundle(
        createdAtMs: createdAtMs,
        app: BundleApp(name: "dish-ios", version: "1.1.0", build: "7"),
        device: BundleDevice(model: "iPhone18,1", os: "iOS 26.1"),
        controllerDb: BundleControllerDb(bundledVersion: 1, activeVersion: 1, source: .bundled, lastCheckAtMs: nil, lastCheckResult: nil),
        controllers: [steamPad, unknownPad],
        hosts: [
            BundleHost(
                alias: "Host 1",
                kind: "satellite",
                version: nil,
                protocolVersion: 4,
                link: "connected",
                grants: BundleGrants(mic: false, speaker: false, hapticAudio: false)
            )
        ],
        log: [BundleLogLine(atMs: createdAtMs - 1000, tag: "padAttached", message: "Xbox Wireless Controller")]
    )

    private func object() throws -> [String: Any] {
        let data = encodeDiagnosticsBundle(Self.bundle)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testTheEnvelopeIsBundleOne() throws {
        let object = try object()
        XCTAssertEqual(object["bundle"] as? Int, 1)
        XCTAssertEqual(object["createdAt"] as? String, "2026-11-19T21:04:11Z")
        XCTAssertEqual(Set(object.keys), ["bundle", "createdAt", "app", "device", "controllerDb", "controllers", "hosts", "log"])
    }

    func testTheAppAndTheDeviceAreNamed() throws {
        let object = try object()
        XCTAssertEqual(object["app"] as? [String: String], ["name": "dish-ios", "version": "1.1.0", "build": "7"])
        XCTAssertEqual(object["device"] as? [String: String], ["model": "iPhone18,1", "os": "iOS 26.1"])
    }

    func testTheDatabaseBeforeItsFirstCheckSaysNullForTheCheck() throws {
        let database = try XCTUnwrap(object()["controllerDb"] as? [String: Any])
        XCTAssertEqual(database["bundledVersion"] as? Int, 1)
        XCTAssertEqual(database["activeVersion"] as? Int, 1)
        XCTAssertEqual(database["source"] as? String, "bundled")
        XCTAssertTrue(database["lastCheckAt"] is NSNull)
        XCTAssertTrue(database["lastCheckResult"] is NSNull)
    }

    func testTheLastCheckIsAnInstantAndAResult() throws {
        let checked = BundleControllerDb(
            bundledVersion: 1,
            activeVersion: 2,
            source: .cache,
            lastCheckAtMs: Self.createdAtMs,
            lastCheckResult: .updated
        )
        let data = try JSONSerialization.jsonObject(with: JSONEncoder().encode(checked)) as? [String: Any]
        XCTAssertEqual(data?["lastCheckAt"] as? String, "2026-11-19T21:04:11Z")
        XCTAssertEqual(data?["lastCheckResult"] as? String, "updated")
        XCTAssertEqual(data?["source"] as? String, "cache")
    }

    func testAControllerCarriesItsRecordItsPathAndWhatTheSystemSaidOfIt() throws {
        let controllers = try XCTUnwrap(object()["controllers"] as? [[String: Any]])
        XCTAssertEqual(controllers.first?["record"] as? String, "valve-steam-controller-2026-bluetooth")
        XCTAssertEqual(controllers.first?["verification"] as? String, "verified")
        XCTAssertEqual(controllers.first?["transport"] as? String, "bluetooth")
        XCTAssertEqual(controllers.first?["path"] as? String, "bluetooth")
        let hardware = try XCTUnwrap(controllers.first?["hardware"] as? [String: Any])
        XCTAssertEqual(hardware["vid"] as? String, "28de")
        XCTAssertEqual(hardware["pid"] as? String, "1303")
        XCTAssertEqual((controllers.first?["outcomes"] as? [Any])?.count, 0, "no test was run")
    }

    func testAControllerNoRecordMatchedSaysNull() throws {
        let controllers = try XCTUnwrap(object()["controllers"] as? [[String: Any]])
        let pad = try XCTUnwrap(controllers.last)
        XCTAssertTrue(pad["record"] is NSNull)
        XCTAssertTrue(pad["verification"] is NSNull)
        XCTAssertTrue(pad["lastFeedback"] is NSNull, "iOS keeps no record of the last feedback")
        XCTAssertEqual(pad["path"] as? String, "gameController")
        let hardware = try XCTUnwrap(pad["hardware"] as? [String: Any])
        XCTAssertEqual(hardware["product"] as? String, "Xbox Wireless Controller")
        XCTAssertEqual(hardware["category"] as? String, "Xbox One")
        XCTAssertTrue(hardware["vid"] is NSNull)
    }

    func testAHostIsAnAliasWithItsKindVersionProtocolLinkAndGrants() throws {
        let host = try XCTUnwrap((object()["hosts"] as? [[String: Any]])?.first)
        XCTAssertEqual(host["alias"] as? String, "Host 1")
        XCTAssertEqual(host["kind"] as? String, "satellite")
        XCTAssertTrue(host["version"] is NSNull)
        XCTAssertEqual(host["protocol"] as? Int, 4)
        XCTAssertEqual(host["link"] as? String, "connected")
        XCTAssertEqual(host["grants"] as? [String: Bool], ["mic": false, "speaker": false, "hapticAudio": false])
    }

    func testTheLogIsTheFlightRecordersLines() throws {
        let line = try XCTUnwrap((object()["log"] as? [[String: Any]])?.first)
        XCTAssertEqual(line["atMs"] as? Int64, Self.createdAtMs - 1000)
        XCTAssertEqual(line["tag"] as? String, "padAttached")
        XCTAssertEqual(line["message"] as? String, "Xbox Wireless Controller")
    }

    func testTheFileIsNamedForTheAppAndTheMomentInTheZoneGiven() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let toronto = try XCTUnwrap(TimeZone(identifier: "America/Toronto"))
        XCTAssertEqual(
            diagnosticsFileName(app: "dish-ios", atMs: Self.createdAtMs, timeZone: utc),
            "dish-diagnostics-dish-ios-20261119-210411.json"
        )
        XCTAssertEqual(
            diagnosticsFileName(app: "dish-ios", atMs: Self.createdAtMs, timeZone: toronto),
            "dish-diagnostics-dish-ios-20261119-160411.json"
        )
    }

    func testTheMailGoesToSupportUnderTheContractsSubject() {
        XCTAssertEqual(DiagnosticsMailAddress.support, "support@tinkernorth.com")
        XCTAssertEqual(
            diagnosticsMailSubject(app: "Dish for iOS", version: "1.1.0", model: "iPhone18,1"),
            "Dish diagnostics: Dish for iOS 1.1.0 on iPhone18,1"
        )
    }
}
