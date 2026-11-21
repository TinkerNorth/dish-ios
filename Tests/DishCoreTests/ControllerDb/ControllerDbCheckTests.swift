// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest

/// The check against the website as decisions: whether it may ask at all,
/// what the manifest's answer means, what the downloaded files make of the
/// cache, and when the next check is due.
final class ControllerDbCheckTests: XCTestCase {

    func testTheResultsAreTheContractsWords() {
        XCTAssertEqual(ControllerDbCheckResult.allCases.map(\.rawValue), ["upToDate", "updated", "offline", "invalid", "off"])
    }

    func testTheSwitchOffSendsNothingAndReadsOff() {
        XCTAssertEqual(controllerDbGate(checksEnabled: false), .stay(.off))
    }

    func testTheSwitchOnAsks() {
        XCTAssertEqual(controllerDbGate(checksEnabled: true), .ask)
    }

    func testTheSiteIsTheContractsAndHoldsNoQuery() throws {
        let base = try XCTUnwrap(URL(string: ControllerDbSchedule.baseURLString))
        XCTAssertEqual(base.host(), "dish.tinkernorth.com")
        XCTAssertEqual(base.scheme, "https")
        XCTAssertEqual(base.path(), "/controllers/v1/")
        XCTAssertNil(base.query())
    }

    // MARK: - The manifest's answer

    func testA304IsNothingNew() {
        XCTAssertEqual(manifestReply(status: 304, body: Data(), etag: nil), .notModified)
        XCTAssertEqual(manifestStep(.notModified, activeVersion: 1), .done(.upToDate))
    }

    func testA200CarriesTheBodyAndItsETag() {
        XCTAssertEqual(manifestReply(status: 200, body: Data("x".utf8), etag: "\"e\""), .body(Data("x".utf8), etag: "\"e\""))
    }

    func testAnyOtherStatusIsNoAnswer() {
        XCTAssertEqual(manifestReply(status: 404, body: Data(), etag: nil), .unreachable)
        XCTAssertEqual(manifestReply(status: 503, body: Data(), etag: nil), .unreachable)
    }

    func testNoAnswerIsOffline() {
        XCTAssertEqual(manifestStep(.unreachable, activeVersion: 1), .done(.offline))
    }

    func testAManifestNoNewerThanTheActiveVersionIsUpToDate() throws {
        let body = try XCTUnwrap(ControllerDbFixtures.publishedFiles(version: 2)[ControllerDbFiles.manifest])
        XCTAssertEqual(manifestStep(.body(body, etag: nil), activeVersion: 2), .done(.upToDate))
        XCTAssertEqual(manifestStep(.body(body, etag: nil), activeVersion: 3), .done(.upToDate))
    }

    func testANewerManifestIsDownloaded() throws {
        let body = try XCTUnwrap(ControllerDbFixtures.publishedFiles(version: 2)[ControllerDbFiles.manifest])
        XCTAssertEqual(
            manifestStep(.body(body, etag: nil), activeVersion: 1),
            try .download(ControllerDbFixtures.publishedManifest(version: 2))
        )
    }

    func testABodyThatIsNotAManifestIsInvalid() {
        XCTAssertEqual(manifestStep(.body(Data("<html>".utf8), etag: nil), activeVersion: 1), .done(.invalid))
    }

    // MARK: - The files it names

    func testFilesThatDidNotAllArriveAreOffline() throws {
        XCTAssertEqual(try installStep(manifest: ControllerDbFixtures.publishedManifest(), files: nil), .done(.offline))
    }

    func testFilesThatDoNotVerifyAreInvalid() throws {
        var files = ControllerDbFixtures.publishedFiles()
        files[ControllerDbFiles.controllers] = Data("{}".utf8)
        XCTAssertEqual(try installStep(manifest: ControllerDbFixtures.publishedManifest(), files: files), .done(.invalid))
    }

    func testFilesThatVerifyAreInstalledWhole() throws {
        let files = ControllerDbFixtures.publishedFiles()
        guard case let .install(set) = try installStep(manifest: ControllerDbFixtures.publishedManifest(), files: files) else {
            return XCTFail("verified files install")
        }
        XCTAssertEqual(set.dbVersion, 2)
    }

    // MARK: - When

    func testTheFirstCheckOfARunIsTenSecondsAfterLaunch() {
        XCTAssertEqual(controllerDbCheckDelayMs(lastCheckThisRunMs: nil, nowMs: 5_000_000), 10000)
    }

    func testTheNextCheckIsSixHoursAfterTheLastOne() {
        let sixHours: Int64 = 6 * 60 * 60 * 1000
        XCTAssertEqual(controllerDbCheckDelayMs(lastCheckThisRunMs: 1_000_000, nowMs: 1_000_000), sixHours)
        XCTAssertEqual(controllerDbCheckDelayMs(lastCheckThisRunMs: 1_000_000, nowMs: 1_000_000 + 3_600_000), sixHours - 3_600_000)
    }

    func testAnOverdueCheckWaitsTheTenSecondsAComingBackAppGives() {
        let sevenHoursLater: Int64 = 1_000_000 + 7 * 60 * 60 * 1000
        XCTAssertEqual(controllerDbCheckDelayMs(lastCheckThisRunMs: 1_000_000, nowMs: sevenHoursLater), 10000)
    }
}
