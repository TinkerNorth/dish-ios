// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Synchronization
import XCTest
@testable import DishEngine

@MainActor
extension ControllerDbStore {
    /// The bundled copy over `defaults`, a cache folder of its own, a gateway
    /// that never answers and a ticker nothing fires: a model's controller
    /// database for a test that is about something else.
    static func offline(defaults: UserDefaults) -> ControllerDbStore {
        ControllerDbStore(
            bundled: BundledControllerDb.load() ?? .empty,
            cache: ControllerDbCache(directory: privateControllerDbFolder()),
            gateway: OfflineControllerDbGateway(),
            preferences: ControllerDbPreferenceStore(defaults: defaults),
            ticker: ManualTicker()
        )
    }
}

/// One request the website was asked.
enum ControllerDbRequest: Hashable {
    case manifest(etag: String?)
    case file(String)
}

/// The website as a test scripts it: a manifest reply and the files it
/// serves, and every request it was asked, in order.
final class ScriptedControllerDbGateway: ControllerDbGateway {
    private struct Script {
        var manifest: ManifestReply = .unreachable
        var files: [String: Data] = [:]
        var requests: [ControllerDbRequest] = []
    }

    private let script = Mutex(Script())

    var requests: [ControllerDbRequest] {
        script.withLock { $0.requests }
    }

    func answer(manifest: ManifestReply, files: [String: Data] = [:]) {
        script.withLock { script in
            script.manifest = manifest
            script.files = files
        }
    }

    /// The website serves a published set: its manifest, under `etag`, and
    /// every file it names.
    func serve(_ published: [String: Data], etag: String = "\"v2\"") {
        let manifest = published[ControllerDbFiles.manifest] ?? Data()
        answer(manifest: .body(manifest, etag: etag), files: published)
    }

    func manifest(etag: String?) async -> ManifestReply {
        script.withLock { script in
            script.requests.append(.manifest(etag: etag))
            return script.manifest
        }
    }

    func file(_ path: String) async -> Data? {
        script.withLock { script in
            script.requests.append(.file(path))
            return script.files[path]
        }
    }
}

/// A cache folder no other test shares, removed when the test ends.
func freshCacheFolder(_ test: XCTestCase) -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
        "controller-db-tests-\(UUID().uuidString)",
        isDirectory: true
    )
    test.addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
    return folder
}
