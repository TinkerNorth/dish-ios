// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation

/// The downloaded controller data, on disk under Application Support: one
/// file per published path, the manifest that vouches for them beside them,
/// so the cache verifies itself as it loads. A new version is written into a
/// folder beside the old one and swapped in whole, so a crash mid-write
/// leaves the previous version. Nothing but the manifest, the database and
/// a locale's strings is ever written.
package final class ControllerDbCache: Repository, Sendable {
    package typealias Key = String
    package typealias Value = Data

    package let directory: URL

    package init(directory: URL) {
        self.directory = directory
    }

    /// `Application Support/Dish/controllers-v1` in the app's container.
    package static func defaultDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let root = support ?? FileManager.default.temporaryDirectory
        return root.appendingPathComponent("Dish", isDirectory: true).appendingPathComponent(BundledControllerDb.folder, isDirectory: true)
    }

    // MARK: - Repository

    package func get(_ key: String) -> Data? {
        guard isCachePath(key) else { return nil }
        return try? Data(contentsOf: url(key))
    }

    package func all() -> [Data] {
        files().keys.sorted().compactMap(get)
    }

    package func put(_ value: Data, for key: String) {
        guard isCachePath(key) else { return }
        write(value, to: url(key))
    }

    package func remove(_ key: String) {
        guard isCachePath(key) else { return }
        removeIfThere(url(key))
    }

    package func clear() {
        removeIfThere(directory)
    }

    // MARK: - The set

    /// The manifest the cache holds and every file it names, by its path;
    /// empty with no manifest.
    package func files() -> [String: Data] {
        guard let body = get(ControllerDbFiles.manifest) else { return [:] }
        guard case let .success(manifest) = decodeControllerDbManifest(body) else { return [ControllerDbFiles.manifest: body] }
        var files = [ControllerDbFiles.manifest: body]
        for path in manifest.files.keys {
            files[path] = get(path)
        }
        return files
    }

    /// The cached set, verified against the manifest stored with it; nil for
    /// none, and for a folder whose files no longer match it.
    package func load() -> ControllerDbSet? {
        let files = files()
        guard let body = files[ControllerDbFiles.manifest],
              case let .success(manifest) = decodeControllerDbManifest(body) else { return nil }
        return verifiedControllerDbSet(manifest: manifest, files: files)
    }

    /// The whole set replaced at once: written into a sibling folder, then
    /// swapped over the old one. False leaves the old set as it was; a path
    /// that is not the database's refuses the whole set.
    package func replaceAll(_ files: [String: Data]) -> Bool {
        guard files.keys.allSatisfy(isCachePath) else { return false }
        let staging = directory.deletingLastPathComponent().appendingPathComponent(
            directory.lastPathComponent + ".staging",
            isDirectory: true
        )
        removeIfThere(staging)
        for (path, data) in files {
            write(data, to: staging.appendingPathComponent(path))
        }
        let staged = files.keys.allSatisfy { FileManager.default.fileExists(atPath: staging.appendingPathComponent($0).path) }
        guard staged else { return false }
        return swap(staging)
    }

    // MARK: - On disk

    private func url(_ key: String) -> URL {
        directory.appendingPathComponent(key)
    }

    private func write(_ data: Data, to file: URL) {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        } catch {
            return
        }
    }

    private func removeIfThere(_ item: URL) {
        guard FileManager.default.fileExists(atPath: item.path) else { return }
        do {
            try FileManager.default.removeItem(at: item)
        } catch {
            return
        }
    }

    /// The staged folder takes the old one's place: moved in when there is
    /// none, else replaced over it in one step.
    private func swap(_ staging: URL) -> Bool {
        do {
            guard FileManager.default.fileExists(atPath: directory.path) else {
                try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: staging, to: directory)
                return true
            }
            let replaced = try FileManager.default.replaceItemAt(directory, withItemAt: staging)
            return replaced != nil
        } catch {
            return false
        }
    }
}

/// The manifest, which the cache keeps beside the files, or a database path.
private func isCachePath(_ path: String) -> Bool {
    path == ControllerDbFiles.manifest || isControllerDbPath(path)
}
