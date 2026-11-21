// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The published set's manifest and the check that turns bytes into a set:
// every file the manifest names, its size and its SHA-256 against the
// manifest, then parsed, then schema 1 and the manifest's version, and only
// then a set the cache may take. A manifest names the paths the cache writes
// under, so it may name nothing but the database and a locale's strings.
// Signing the manifest is the next integrity step (section 11); schema 1
// relies on HTTPS and these digests.

import CryptoKit
import Foundation

package struct ControllerDbFileEntry: Equatable {
    /// Lowercase hex.
    package let sha256: String
    package let bytes: Int

    package init(sha256: String, bytes: Int) {
        self.sha256 = sha256
        self.bytes = bytes
    }
}

package struct ControllerDbManifest: Equatable {
    package let dbVersion: Int
    /// By the path under `/controllers/v1/`: "controllers.json", "strings/en.json".
    package let files: [String: ControllerDbFileEntry]

    package init(dbVersion: Int, files: [String: ControllerDbFileEntry]) {
        self.dbVersion = dbVersion
        self.files = files
    }
}

package enum ControllerDbFiles {
    package static let manifest = "manifest.json"
    package static let controllers = "controllers.json"

    package static func strings(_ locale: String) -> String {
        "strings/\(locale).json"
    }
}

package enum ControllerDbLimits {
    /// No served file is larger; today's `controllers.json` is about 370 KB.
    package static let maxFileBytes = 4 * 1024 * 1024
}

/// The database, or one locale's strings: a path that cannot reach outside
/// the folder it is written under.
package func isControllerDbPath(_ path: String) -> Bool {
    path.wholeMatch(of: /controllers\.json|strings\/[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})?\.json/) != nil
}

/// Lowercase hex SHA-256 of the exact bytes, as the manifest gives it.
package func controllerDbDigest(_ data: Data) -> String {
    hexEncodeLower(SHA256.hash(data: data))
}

private struct ManifestFile: Decodable {
    struct Entry: Decodable {
        let sha256: String
        let bytes: Int
    }

    let schema: Int?
    let dbVersion: Int?
    let files: [String: Entry]?
}

/// A manifest of version 1 or above that names the database and English,
/// nothing outside the database's paths, and no file over the cap.
package func decodeControllerDbManifest(_ data: Data) -> Result<ControllerDbManifest, ControllerDbError> {
    guard let file = try? JSONDecoder().decode(ManifestFile.self, from: data) else { return .failure(.badJson) }
    guard file.schema == ControllerDbSchema.version else { return .failure(.unsupportedSchema) }
    guard let dbVersion = file.dbVersion, dbVersion >= 1, let entries = file.files else { return .failure(.badJson) }
    let namesTheDatabase = entries[ControllerDbFiles.controllers] != nil
    let namesEnglish = entries[ControllerDbFiles.strings(ControllerStrings.fallbackLocale)] != nil
    let namesOnlyDatabasePaths = entries.keys.allSatisfy(isControllerDbPath)
    let fitsTheCap = entries.values.allSatisfy { (0 ... ControllerDbLimits.maxFileBytes).contains($0.bytes) }
    guard namesTheDatabase, namesEnglish, namesOnlyDatabasePaths, fitsTheCap else { return .failure(.badJson) }
    let files = entries.mapValues { ControllerDbFileEntry(sha256: $0.sha256.lowercased(), bytes: $0.bytes) }
    return .success(ControllerDbManifest(dbVersion: dbVersion, files: files))
}

/// The exact bytes the manifest names: its size, then its digest.
package func fileMatches(_ data: Data, _ entry: ControllerDbFileEntry) -> Bool {
    let sizeMatches = data.count == entry.bytes
    return sizeMatches && controllerDbDigest(data) == entry.sha256
}

/// One published version, whole: the manifest, the records and the words.
package struct ControllerDbSet: Equatable {
    package let manifest: ControllerDbManifest
    package let database: ControllerDatabase
    package let strings: ControllerStrings

    package init(manifest: ControllerDbManifest, database: ControllerDatabase, strings: ControllerStrings) {
        self.manifest = manifest
        self.database = database
        self.strings = strings
    }

    package var dbVersion: Int {
        database.dbVersion
    }

    /// What the index holds when no copy loads: nothing, at version 0.
    package static let empty = ControllerDbSet(
        manifest: ControllerDbManifest(dbVersion: 0, files: [:]),
        database: ControllerDatabase(dbVersion: 0, records: []),
        strings: ControllerStrings(tables: [:])
    )
}

/// The files of one version, verified against its manifest and parsed. A
/// file the manifest names that is missing or differs, a database that does
/// not parse, is not schema 1 or is not the manifest's version, and a strings
/// file that does not parse each refuse the whole set.
package func verifiedControllerDbSet(manifest: ControllerDbManifest, files: [String: Data]) -> ControllerDbSet? {
    let everyFileMatches = manifest.files.allSatisfy { path, entry in
        files[path].map { fileMatches($0, entry) } ?? false
    }
    guard everyFileMatches else { return nil }
    guard let body = files[ControllerDbFiles.controllers],
          case let .success(database) = decodeControllerDatabase(body),
          database.dbVersion == manifest.dbVersion else { return nil }
    guard let tables = stringTables(manifest: manifest, files: files) else { return nil }
    return ControllerDbSet(manifest: manifest, database: database, strings: ControllerStrings(tables: tables))
}

/// Every locale the manifest names, by its locale; nil when one does not parse.
private func stringTables(manifest: ControllerDbManifest, files: [String: Data]) -> [String: [String: String]]? {
    var tables: [String: [String: String]] = [:]
    for locale in ControllerStrings.locales {
        let path = ControllerDbFiles.strings(locale)
        guard manifest.files[path] != nil, let data = files[path] else { continue }
        guard case let .success(table) = decodeControllerStrings(data) else { return nil }
        tables[locale] = table
    }
    return tables
}
