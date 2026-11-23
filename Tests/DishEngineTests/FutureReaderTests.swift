// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// A dbVersion 2 from the future, served byte for byte to the production
/// check with the bundled dbVersion 1 in force: a reader released today
/// takes it, and no record's trouble costs another record. The fixture is
/// dish-website's future-reader set; its EXPECT.md is the table these follow.
/// iOS has no Direct path and looks a record up only for a pad it reads
/// over Bluetooth, so "applied" never happens here: a record gives words
/// (its name, its verification, its issues) and nothing else.
@MainActor
final class FutureReaderTests: XCTestCase {

    private let gateway = ScriptedControllerDbGateway()
    private var folder: URL!

    override func setUp() async throws {
        folder = freshCacheFolder(self)
    }

    /// The check run once against the served set.
    private func checked() async throws -> ControllerDbStore {
        let fixture = try FutureReaderFixture()
        gateway.answer(manifest: .body(fixture.manifest, etag: "\"future\""), files: fixture.files)
        let store = try ControllerDbStore(
            bundled: XCTUnwrap(BundledControllerDb.load()),
            cache: ControllerDbCache(directory: folder),
            gateway: gateway,
            preferences: ControllerDbPreferenceStore(defaults: TestDefaults.fresh(self)),
            ticker: ManualTicker()
        )
        store.checkNow()
        await store.settle()
        return store
    }

    // MARK: - The whole set

    func testTheCheckEndsUpdatedAndVersion2ReplacesVersion1Whole() async throws {
        let store = try await checked()
        XCTAssertEqual(store.status.lastCheckResult, .updated)
        XCTAssertEqual(store.status.activeVersion, 2)
        XCTAssertEqual(store.index.source, .cache)
        let bundled = try XCTUnwrap(BundledControllerDb.load())
        XCTAssertTrue(bundled.database.records.contains { $0.bluetooth == ["28de:1303"] }, "version 1 names the 2026 Steam Controller")
        XCTAssertNil(store.index.record(bluetooth: "28de:1303"), "version 2 does not, and records are never merged")
    }

    func testTheManifestsUnknownSignatureIsIgnored() throws {
        let fixture = try FutureReaderFixture()
        XCTAssertTrue(try XCTUnwrap(String(bytes: fixture.manifest, encoding: .utf8)).contains("\"signature\""))
        XCTAssertEqual(try decodeControllerDbManifest(fixture.manifest).get().dbVersion, 2)
    }

    /// The manifest's paths are all the database's (`isControllerDbPath`),
    /// so the set is taken and `strings/it.json` is stored as published;
    /// Italian then reads the English table.
    func testALocaleTheBuildDoesNotShipIsStoredAndNothingElseIsWritten() async throws {
        let store = try await checked()
        XCTAssertFalse(ControllerStrings.locales.contains("it"))
        let fixture = try FutureReaderFixture()
        let stored = ControllerDbCache(directory: folder).files()
        XCTAssertEqual(Set(stored.keys), Set(fixture.files.keys).union([ControllerDbFiles.manifest]))
        XCTAssertEqual(stored[ControllerDbFiles.strings("it")], fixture.files[ControllerDbFiles.strings("it")])
        let written = try FileManager.default.subpathsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".json") }
        XCTAssertEqual(Set(written), Set(stored.keys), "no file but the ones the manifest names")
        XCTAssertEqual(store.index.strings.controllerName("future-pad-served", locale: "it"), "Future Pad (served)")
    }

    func testTheDatabasesUnknownGeneratedByIsIgnored() throws {
        let fixture = try FutureReaderFixture()
        let body = try XCTUnwrap(fixture.files[ControllerDbFiles.controllers])
        XCTAssertTrue(try XCTUnwrap(String(bytes: body, encoding: .utf8)).contains("\"generatedBy\""))
        XCTAssertEqual(try decodeControllerDatabase(body).get().dbVersion, 2)
    }

    /// The mapping object is never decoded here, so its row is held like
    /// any other; only the misauthored row, whose verification no build
    /// names, is left out, and it alone.
    func testEveryRecordIsAccountedForAndNoneCostsAnother() async throws {
        let store = try await checked()
        let byUsb = FutureReaderFixture.usbIds.map { store.index.record(usb: $0)?.id }
        XCTAssertEqual(byUsb, [
            "sony-dualsense", "xbox-360-controller", "future-pad-served", "future-pad-served-ds4",
            "future-pad-new-family", "future-pad-new-op", "8bitdo-m30-d-input", nil
        ])
        XCTAssertEqual(store.index.record(bluetooth: "28de:1106")?.id, "valve-steam-controller-bluetooth")
    }

    // MARK: - Record by record

    func testTheDualSenseIsAsUsableAsInVersion1AndKeepsBothIssues() async throws {
        let store = try await checked()
        let served = try XCTUnwrap(store.index.record(usb: "054c:0ce6"))
        let bundled = try XCTUnwrap(BundledControllerDb.load()).database.records.first { $0.id == "sony-dualsense" }
        XCTAssertEqual(served.family, bundled?.family)
        XCTAssertEqual(served.verification, bundled?.verification)
        XCTAssertEqual(served.issues.map(\.id), ["thor-ds5-rumble-usb", "future-os-as-text"])
    }

    func testAnOsGivenAsTextMatchesByItsMajorVersionAndAnotherPlatformsKeyDoesNot() async throws {
        let store = try await checked()
        let issues = try XCTUnwrap(store.index.record(usb: "054c:0ce6")).issues
        let onIOS26 = ControllerHost(model: "Future Handheld", platform: DiagnosticsApp.platform, osMajor: 26)
        let onIOS15 = ControllerHost(model: "Future Handheld", platform: DiagnosticsApp.platform, osMajor: 15)
        XCTAssertEqual(issuesShown(issues, transport: .usb, host: onIOS26).map(\.id), ["future-os-as-text"], "\"26.2\" is iOS 26")
        XCTAssertEqual(issuesShown(issues, transport: .usb, host: onIOS15), [], "Android's \"15\" is not iOS 15")
    }

    /// iOS never looks a pad up by its USB id (GameController names none),
    /// so the record needing a future family is held, named and never
    /// applied; the build's own reading of the pad is GameController's.
    func testTheXbox360RecordNeedingAFutureFamilyIsHeldAndNeverApplied() async throws {
        let store = try await checked()
        let served = try XCTUnwrap(store.index.record(usb: "045e:028e"))
        XCTAssertEqual(served.family, "futureFamily")
        XCTAssertNil(store.index.record(bluetooth: "045e:028e"), "the one lookup iOS makes finds nothing")
    }

    /// Neither family's Direct path runs on iOS: both served-only pads are
    /// named and never applied, and no platform's rule, `futureos` included,
    /// is read.
    func testBothServedOnlyPadsAreNamedAndNeverApplied() async throws {
        let store = try await checked()
        XCTAssertEqual(store.index.record(usb: "1209:0f02")?.family, "xinput360")
        XCTAssertEqual(store.index.record(usb: "1209:0f05")?.family, "dualshock4")
        XCTAssertEqual(
            store.index.strings.controllerName("future-pad-served-ds4", locale: "en"),
            "Future Pad (served, DualShock 4 protocol)"
        )
        XCTAssertNil(store.index.record(bluetooth: "1209:0f02"))
        XCTAssertNil(store.index.record(bluetooth: "1209:0f05"))
    }

    func testARecordNeedingAFutureFamilyOrAFutureOpIsHeldAndNeverApplied() async throws {
        let store = try await checked()
        XCTAssertEqual(store.index.record(usb: "1209:0f01")?.family, "futureFamily")
        XCTAssertEqual(store.index.record(usb: "1209:0f03")?.id, "future-pad-new-op")
        XCTAssertNil(store.index.record(bluetooth: "1209:0f01"))
        XCTAssertNil(store.index.record(bluetooth: "1209:0f03"))
    }

    /// iOS has no row of its own for the pad; the mapping is not read, so
    /// the record is held for its words and drives nothing.
    func testTheMappingObjectRowIsHeldForItsWordsAndCostsNoOtherRecord() async throws {
        let store = try await checked()
        XCTAssertEqual(store.index.record(usb: "2dc8:5006")?.verification, .imported)
    }

    func testTheMisauthoredRowIsLeftOutAndItsIssueNeverShows() async throws {
        let store = try await checked()
        XCTAssertNil(store.index.record(usb: "1209:0f04"))
        XCTAssertNil(store.index.record(bluetooth: "1209:0f04"))
    }

    func testTheSteamControllerOverBluetoothIsAsInVersion1() async throws {
        let store = try await checked()
        let served = try XCTUnwrap(store.index.record(bluetooth: "28de:1106"))
        let bundled = try XCTUnwrap(BundledControllerDb.load()).database.records.first { $0.id == served.id }
        XCTAssertEqual(served, bundled)
    }
}

/// The future-reader set as committed under `Fixtures/future-reader`.
private struct FutureReaderFixture {
    static let paths = [ControllerDbFiles.controllers] + ["en", "bs", "de", "es", "fr", "pt-BR", "it"].map(ControllerDbFiles.strings)
    /// Every USB id the set names, in its order.
    static let usbIds = ["054c:0ce6", "045e:028e", "1209:0f02", "1209:0f05", "1209:0f01", "1209:0f03", "2dc8:5006", "1209:0f04"]

    let manifest: Data
    let files: [String: Data]

    init(folder: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/future-reader")) throws
    {
        manifest = try Data(contentsOf: folder.appendingPathComponent(ControllerDbFiles.manifest))
        var files: [String: Data] = [:]
        for path in Self.paths {
            files[path] = try Data(contentsOf: folder.appendingPathComponent(path))
        }
        self.files = files
    }
}
