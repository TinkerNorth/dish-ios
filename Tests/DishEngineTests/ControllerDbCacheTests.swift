// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The downloaded data on disk, a `Repository` of files by their published
/// path: it keeps the manifest beside them and verifies itself as it loads,
/// swaps a version in whole, and writes nothing outside the database's paths.
final class ControllerDbCacheTests: XCTestCase {

    private func cache() -> ControllerDbCache {
        ControllerDbCache(directory: freshCacheFolder(self))
    }

    func testAFileIsKeptUnderItsPathAndRemoved() {
        let cache = cache()
        cache.put(Data("a".utf8), for: "strings/en.json")
        XCTAssertEqual(cache.get("strings/en.json"), Data("a".utf8))
        cache.remove("strings/en.json")
        XCTAssertNil(cache.get("strings/en.json"))
    }

    func testAllIsEveryFileTheManifestNames() {
        let cache = cache()
        XCTAssertTrue(cache.replaceAll(ControllerDbFixtures.publishedFiles()))
        XCTAssertEqual(cache.all().count, 4, "the manifest and the three files it names")
    }

    func testClearEmptiesTheCache() {
        let cache = cache()
        XCTAssertTrue(cache.replaceAll(ControllerDbFixtures.publishedFiles()))
        cache.clear()
        XCTAssertEqual(cache.all(), [])
        XCTAssertNil(cache.load())
    }

    func testAPathOutsideTheDatabaseIsNeitherWrittenNorRead() {
        let cache = cache()
        cache.put(Data("x".utf8), for: "../escape.json")
        XCTAssertNil(cache.get("../escape.json"))
        let outside = cache.directory.deletingLastPathComponent().appendingPathComponent("escape.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.path))
    }

    func testASetWithAPathOutsideTheDatabaseIsRefusedWhole() {
        let cache = cache()
        var files = ControllerDbFixtures.publishedFiles()
        files["../escape.json"] = Data()
        XCTAssertFalse(cache.replaceAll(files))
        XCTAssertNil(cache.load())
    }

    func testAnEmptyCacheLoadsNothing() {
        XCTAssertNil(cache().load())
    }

    func testAVersionSwappedInLoadsVerified() {
        let cache = cache()
        XCTAssertTrue(cache.replaceAll(ControllerDbFixtures.publishedFiles(version: 2)))
        XCTAssertEqual(cache.load()?.dbVersion, 2)
    }

    func testANewerVersionReplacesTheOldOneWhole() {
        let cache = cache()
        XCTAssertTrue(cache.replaceAll(ControllerDbFixtures.publishedFiles(version: 2)))
        var next = ControllerDbFixtures.publishedFiles(version: 3)
        next[ControllerDbFiles.strings("de")] = nil
        next[ControllerDbFiles.manifest] = ControllerDbFixtures.manifest(
            for: next.filter { $0.key != ControllerDbFiles.manifest },
            version: 3
        )
        XCTAssertTrue(cache.replaceAll(next))
        XCTAssertEqual(cache.load()?.dbVersion, 3)
        XCTAssertNil(cache.get(ControllerDbFiles.strings("de")), "the old version's files go with it")
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.directory.path + ".staging"))
    }

    func testTheDefaultFolderIsDishsUnderApplicationSupport() {
        let folder = ControllerDbCache.defaultDirectory()
        XCTAssertEqual(folder.lastPathComponent, "controllers-v1")
        XCTAssertEqual(folder.deletingLastPathComponent().lastPathComponent, "Dish")
        XCTAssertEqual(folder.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "Application Support")
    }
}
