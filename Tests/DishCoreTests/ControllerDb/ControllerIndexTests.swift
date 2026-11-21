// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest

/// The index from `vid:pid` to record: the bundled set, or the cached one
/// when its version is greater, replaced whole; and which of a record's
/// issues a pad on this device shows.
final class ControllerIndexTests: XCTestCase {

    private func set(version: Int) throws -> ControllerDbSet {
        try XCTUnwrap(verifiedControllerDbSet(
            manifest: ControllerDbFixtures.publishedManifest(version: version),
            files: ControllerDbFixtures.publishedFiles(version: version)
        ))
    }

    func testAPadIsFoundByItsBluetoothId() throws {
        let index = try ControllerIndex(set(version: 1), source: .bundled)
        XCTAssertEqual(index.record(bluetooth: "28de:1303")?.id, "valve-steam-controller-2026-bluetooth")
        XCTAssertNil(index.record(bluetooth: "054c:0ce6"), "a USB id is not a Bluetooth one")
    }

    func testAPadIsFoundByItsUsbId() throws {
        let index = try ControllerIndex(set(version: 1), source: .bundled)
        XCTAssertEqual(index.record(usb: "054c:0ce6")?.id, "sony-dualsense")
        XCTAssertNil(index.record(usb: "28de:1303"))
    }

    func testAnIdIsMatchedWhateverItsCase() throws {
        let index = try ControllerIndex(set(version: 1), source: .bundled)
        XCTAssertEqual(index.record(bluetooth: "28DE:1303")?.id, "valve-steam-controller-2026-bluetooth")
    }

    func testTheKeyIsFourLowercaseHexDigitsEach() {
        XCTAssertEqual(controllerIdentity(vendorId: 0x28DE, productId: 0x1303), "28de:1303")
        XCTAssertEqual(controllerIdentity(vendorId: 0x054C, productId: 0x0CE6), "054c:0ce6")
    }

    func testTheFirstRecordToNameAnIdKeepsIt() throws {
        let second = ControllerDbFixtures.tritonRecord.replacingOccurrences(of: "valve-steam-controller-2026-bluetooth", with: "a-copy")
        let data = [
            ControllerDbFiles.controllers: ControllerDbFixtures.database([ControllerDbFixtures.tritonRecord, second]),
            ControllerDbFiles.strings("en"): ControllerDbFixtures.english
        ]
        let manifest = try decodeControllerDbManifest(ControllerDbFixtures.manifest(for: data)).get()
        let index = try ControllerIndex(XCTUnwrap(verifiedControllerDbSet(manifest: manifest, files: data)), source: .bundled)
        XCTAssertEqual(index.record(bluetooth: "28de:1303")?.id, "valve-steam-controller-2026-bluetooth")
    }

    func testTheBundledSetIsInForceWithNoCache() throws {
        let index = try activeControllerIndex(bundled: set(version: 1), cached: nil)
        XCTAssertEqual(index.source, .bundled)
        XCTAssertEqual(index.dbVersion, 1)
    }

    func testANewerCacheReplacesTheBundledSetWhole() throws {
        let index = try activeControllerIndex(bundled: set(version: 1), cached: set(version: 2))
        XCTAssertEqual(index.source, .cache)
        XCTAssertEqual(index.dbVersion, 2)
    }

    func testACacheNoNewerThanTheBundledSetIsNotUsed() throws {
        XCTAssertEqual(try activeControllerIndex(bundled: set(version: 2), cached: set(version: 2)).source, .bundled)
        XCTAssertEqual(try activeControllerIndex(bundled: set(version: 3), cached: set(version: 2)).source, .bundled)
    }

    func testTheBundledIndexKnowsBothSteamControllersOverBluetooth() throws {
        let index = try ControllerIndex(XCTUnwrap(BundledControllerDb.load()), source: .bundled)
        XCTAssertEqual(index.record(bluetooth: "28de:1106")?.id, "valve-steam-controller-bluetooth")
        XCTAssertEqual(index.record(bluetooth: "28de:1303")?.id, "valve-steam-controller-2026-bluetooth")
    }

    // MARK: - The issues a pad shows

    private static let anywhere = ControllerIssue(id: "anywhere")
    private static let overBluetooth = ControllerIssue(id: "ble", transport: .bluetooth)
    private static let overUsb = ControllerIssue(id: "usb", transport: .usb)
    private static let onThisPhone = ControllerIssue(id: "phone", device: "iPhone18,1", transport: .bluetooth)
    private static let onAnotherDevice = ControllerIssue(id: "thor", device: "AYN Thor", transport: .bluetooth)
    private static let onThisIOS = ControllerIssue(id: "ios26", os: ["ios": 26], transport: .bluetooth)
    private static let onAnotherIOS = ControllerIssue(id: "ios25", os: ["ios": 25])
    private static let onAndroid = ControllerIssue(id: "android", os: ["android": 15])

    private static let host = ControllerHost(model: "iPhone18,1", platform: "ios", osMajor: 26)

    func testAnIssueOnThisTransportOrNoneShows() {
        let issues = [Self.anywhere, Self.overBluetooth, Self.overUsb]
        XCTAssertEqual(issuesShown(issues, transport: .bluetooth, host: Self.host).map(\.id), ["anywhere", "ble"])
    }

    func testAnIssueOnThisDeviceOrNoneShows() {
        let issues = [Self.onThisPhone, Self.onAnotherDevice]
        XCTAssertEqual(issuesShown(issues, transport: .bluetooth, host: Self.host).map(\.id), ["phone"])
    }

    func testAnIssueOnThisSystemsVersionOrNoneShows() {
        let issues = [Self.onThisIOS, Self.onAnotherIOS, Self.onAndroid]
        XCTAssertEqual(issuesShown(issues, transport: .bluetooth, host: Self.host).map(\.id), ["ios26"])
    }

    func testOnlyAnOpenIssueShows() {
        let fixed = ControllerIssue(id: "fixed", transport: .bluetooth, open: false)
        XCTAssertEqual(issuesShown([fixed, Self.overBluetooth], transport: .bluetooth, host: Self.host).map(\.id), ["ble"])
    }

    func testAHostWhoseVersionIsUnknownShowsNoIssueTiedToOne() {
        let unknown = ControllerHost(model: "iPhone18,1", platform: "ios", osMajor: nil)
        XCTAssertEqual(issuesShown([Self.onThisIOS, Self.anywhere], transport: .bluetooth, host: unknown).map(\.id), ["anywhere"])
    }
}
