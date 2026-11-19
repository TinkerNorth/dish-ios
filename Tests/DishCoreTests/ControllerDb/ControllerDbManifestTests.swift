// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest

/// The manifest and the check that turns downloaded bytes into a set: every
/// file it names, by size and SHA-256, then parsed, then schema 1 and the
/// manifest's version; and the bundled copy, which holds to its own manifest.
final class ControllerDbManifestTests: XCTestCase {

    func testAManifestNamesItsVersionAndEachFilesDigestAndSize() throws {
        let manifest = try ControllerDbFixtures.publishedManifest(version: 3)
        let english = ControllerDbFixtures.english
        XCTAssertEqual(manifest.dbVersion, 3)
        XCTAssertEqual(
            manifest.files[ControllerDbFiles.strings("en")],
            ControllerDbFileEntry(sha256: controllerDbDigest(english), bytes: english.count)
        )
        XCTAssertEqual(manifest.files.count, 3)
    }

    func testAManifestOfAnotherSchemaIsRefused() {
        let body = ControllerDbFixtures.manifest(
            for: [ControllerDbFiles.controllers: Data(), ControllerDbFiles.strings("en"): Data()],
            schema: 2
        )
        XCTAssertEqual(decodeControllerDbManifest(body), .failure(.unsupportedSchema))
    }

    func testAManifestThatIsNotJsonIsRefused() {
        XCTAssertEqual(decodeControllerDbManifest(Data("<html>".utf8)), .failure(.badJson))
    }

    func testAManifestWithoutTheDatabaseOrEnglishIsRefused() {
        let noDatabase = ControllerDbFixtures.manifest(for: [ControllerDbFiles.strings("en"): Data()])
        let noEnglish = ControllerDbFixtures.manifest(for: [ControllerDbFiles.controllers: Data()])
        XCTAssertEqual(decodeControllerDbManifest(noDatabase), .failure(.badJson))
        XCTAssertEqual(decodeControllerDbManifest(noEnglish), .failure(.badJson))
    }

    func testAManifestBelowVersionOneIsRefused() {
        let body = ControllerDbFixtures.manifest(
            for: [ControllerDbFiles.controllers: Data(), ControllerDbFiles.strings("en"): Data()],
            version: 0
        )
        XCTAssertEqual(decodeControllerDbManifest(body), .failure(.badJson))
    }

    func testAManifestNamingAPathOutsideTheDatabaseIsRefused() {
        for path in ["../escape.json", "strings/../../x.json", "schema/controller-db.schema.json", "strings/en.txt", "/etc/passwd"] {
            let body = ControllerDbFixtures.manifest(for: [
                ControllerDbFiles.controllers: Data(),
                ControllerDbFiles.strings("en"): Data(),
                path: Data()
            ])
            XCTAssertEqual(decodeControllerDbManifest(body), .failure(.badJson), path)
        }
    }

    func testAManifestNamingAFileLargerThanTheCapIsRefused() {
        let body = Data("""
        { "schema": 1, "dbVersion": 2, "files": {
          "controllers.json": { "sha256": "00", "bytes": \(ControllerDbLimits.maxFileBytes + 1) },
          "strings/en.json": { "sha256": "00", "bytes": 1 } } }
        """.utf8)
        XCTAssertEqual(decodeControllerDbManifest(body), .failure(.badJson))
    }

    func testOnlyTheDatabaseAndALocalesStringsAreDatabasePaths() {
        XCTAssertTrue(isControllerDbPath("controllers.json"))
        XCTAssertTrue(isControllerDbPath("strings/pt-BR.json"))
        XCTAssertFalse(isControllerDbPath("manifest.json"), "the manifest is stored by the cache itself, never named by one")
        XCTAssertFalse(isControllerDbPath("strings/../controllers.json"))
        XCTAssertFalse(isControllerDbPath("strings/en.json/x"))
    }

    func testFilesThatMatchTheirManifestMakeASet() throws {
        let files = ControllerDbFixtures.publishedFiles(version: 2)
        let set = try XCTUnwrap(verifiedControllerDbSet(manifest: ControllerDbFixtures.publishedManifest(version: 2), files: files))
        XCTAssertEqual(set.dbVersion, 2)
        XCTAssertEqual(set.database.records.count, 2)
        XCTAssertEqual(set.strings.text("issue.triton-ble-lag.title", locale: "de"), "Eingaben kommen spät an")
    }

    func testAFileOfTheWrongSizeRefusesTheSet() throws {
        var files = ControllerDbFixtures.publishedFiles(version: 2)
        files[ControllerDbFiles.strings("de")] = ControllerDbFixtures.german + Data(" ".utf8)
        XCTAssertNil(try verifiedControllerDbSet(manifest: ControllerDbFixtures.publishedManifest(version: 2), files: files))
    }

    func testAFileOfTheRightSizeAndTheWrongDigestRefusesTheSet() throws {
        var files = ControllerDbFixtures.publishedFiles(version: 2)
        var english = ControllerDbFixtures.english
        english[english.startIndex + 4] = UInt8(ascii: "X")
        files[ControllerDbFiles.strings("en")] = english
        XCTAssertNil(try verifiedControllerDbSet(manifest: ControllerDbFixtures.publishedManifest(version: 2), files: files))
    }

    func testAMissingFileRefusesTheSet() throws {
        var files = ControllerDbFixtures.publishedFiles(version: 2)
        files[ControllerDbFiles.strings("de")] = nil
        XCTAssertNil(try verifiedControllerDbSet(manifest: ControllerDbFixtures.publishedManifest(version: 2), files: files))
    }

    func testADatabaseOfAnotherVersionThanTheManifestRefusesTheSet() throws {
        let data = [
            ControllerDbFiles.controllers: ControllerDbFixtures.database([ControllerDbFixtures.tritonRecord], version: 5),
            ControllerDbFiles.strings("en"): ControllerDbFixtures.english
        ]
        let manifest = try decodeControllerDbManifest(ControllerDbFixtures.manifest(for: data, version: 4)).get()
        XCTAssertNil(verifiedControllerDbSet(manifest: manifest, files: data))
    }

    func testADatabaseOfAnotherSchemaRefusesTheSet() throws {
        let data = [
            ControllerDbFiles.controllers: ControllerDbFixtures.database([ControllerDbFixtures.tritonRecord], version: 4, schema: 2),
            ControllerDbFiles.strings("en"): ControllerDbFixtures.english
        ]
        let manifest = try decodeControllerDbManifest(ControllerDbFixtures.manifest(for: data, version: 4)).get()
        XCTAssertNil(verifiedControllerDbSet(manifest: manifest, files: data))
    }

    func testAStringsFileThatDoesNotParseRefusesTheSet() throws {
        let data = [
            ControllerDbFiles.controllers: ControllerDbFixtures.database([ControllerDbFixtures.tritonRecord], version: 4),
            ControllerDbFiles.strings("en"): Data("[1]".utf8)
        ]
        let manifest = try decodeControllerDbManifest(ControllerDbFixtures.manifest(for: data, version: 4)).get()
        XCTAssertNil(verifiedControllerDbSet(manifest: manifest, files: data))
    }

    func testTheDigestIsLowercaseHexSHA256() {
        XCTAssertEqual(controllerDbDigest(Data()), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testTheBundledCopyHoldsToItsOwnManifest() throws {
        let set = try XCTUnwrap(BundledControllerDb.load(), "every bundled file matches the manifest it shipped with")
        XCTAssertEqual(set.dbVersion, 1)
        XCTAssertEqual(set.database.records.count, 272)
        XCTAssertEqual(Set(set.strings.tables.keys), Set(ControllerStrings.locales))
    }

    func testABundleWithoutTheFilesLoadsNothing() {
        XCTAssertNil(BundledControllerDb.load(in: Bundle(for: ControllerDbManifestTests.self)))
    }
}
