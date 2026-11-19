// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The copy of the database the app was built with: dbVersion 1, the files
// under `Resources/controllers-v1`, byte for byte as dish-website publishes
// them. A client never edits its copy; a newer one comes from the website.

import Foundation

package enum BundledControllerDb {
    package static let folder = "controllers-v1"

    /// Every file of the bundled version by its published path, the manifest
    /// among them; empty in a bundle that carries none.
    package static func files(in bundle: Bundle = .module) -> [String: Data] {
        guard let root = bundle.resourceURL?.appendingPathComponent(folder, isDirectory: true) else { return [:] }
        let paths = [ControllerDbFiles.manifest, ControllerDbFiles.controllers] + ControllerStrings.locales.map(ControllerDbFiles.strings)
        var files: [String: Data] = [:]
        for path in paths {
            files[path] = try? Data(contentsOf: root.appendingPathComponent(path))
        }
        return files
    }

    /// The bundled set, verified against its own manifest; nil only for a
    /// build that shipped a broken copy, which the tests refuse.
    package static func load(in bundle: Bundle = .module) -> ControllerDbSet? {
        let files = files(in: bundle)
        guard let body = files[ControllerDbFiles.manifest],
              case let .success(manifest) = decodeControllerDbManifest(body) else { return nil }
        return verifiedControllerDbSet(manifest: manifest, files: files)
    }
}
