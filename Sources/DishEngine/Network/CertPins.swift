// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The TOFU pins: each satellite host's SHA-256 certificate fingerprint,
/// pinned on first contact. The TLS delegate reads and writes them on
/// URLSession's queue while the main actor may be migrating one, so they sit
/// behind a lock and persist to a JSON file of their own (dish-mac keeps
/// them in `UserDefaults`, which iOS's SDK does not let cross threads). A
/// nil file keeps them in memory, for tests.
package final class CertPins: Sendable {
    private let pins: TrackedLock<[String: String]>
    private let file: URL?

    package init(file: URL?) {
        self.file = file
        pins = TrackedLock(Self.load(file), "connection.pins")
    }

    /// `Application Support/Dish/cert-pins.json` in the app's container.
    package static func defaultFile() -> URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return base?.appendingPathComponent("Dish", isDirectory: true).appendingPathComponent("cert-pins.json")
    }

    /// Nil only when never pinned: an empty pin is cleared at write time.
    func pin(host: String) -> String? {
        pins.withLock { $0[host] }
    }

    func setPin(host: String, fingerprintHex: String) {
        let file = file
        pins.withLock { current in
            current[host] = fingerprintHex.isEmpty ? nil : fingerprintHex
            Self.save(current, to: file)
        }
    }

    func forget(host: String) {
        let file = file
        pins.withLock { current in
            guard current.removeValue(forKey: host) != nil else { return }
            Self.save(current, to: file)
        }
    }

    private static func load(_ file: URL?) -> [String: String] {
        guard let file, let data = try? Data(contentsOf: file),
              let pins = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return pins
    }

    /// Best-effort: a pin that fails to persist is pinned again on the next
    /// launch's first contact.
    private static func save(_ pins: [String: String], to file: URL?) {
        guard let file, let data = try? JSONEncoder().encode(pins) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
