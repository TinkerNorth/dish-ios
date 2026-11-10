// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest

/// A String Catalog as the tree holds it: its source language and, for each
/// key, every language's plain value or plural forms, with their states.
struct StringCatalogFile {

    struct Entry {
        let key: String
        /// language → the value of a plain entry.
        let plain: [String: String]
        /// language → CLDR plural category → value.
        let plural: [String: [String: String]]
        let states: [String]

        var languages: Set<String> {
            Set(plain.keys).union(plural.keys)
        }
    }

    let sourceLanguage: String
    let entries: [Entry]

    var keys: Set<String> {
        Set(entries.map(\.key))
    }

    init(_ relativePath: String) throws {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(RepoFiles.read(relativePath).utf8)) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        sourceLanguage = root["sourceLanguage"] as? String ?? ""
        entries = try strings.map { key, raw in try Self.entry(key: key, raw) }.sorted { $0.key < $1.key }
    }

    private static func entry(key: String, _ raw: Any) throws -> Entry {
        let entry = try XCTUnwrap(raw as? [String: Any], key)
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key)
        var plain: [String: String] = [:]
        var plural: [String: [String: String]] = [:]
        var states: [String] = []
        for (code, rawLocalization) in localizations {
            let localization = try XCTUnwrap(rawLocalization as? [String: Any], "\(key) in \(code)")
            if let unit = localization["stringUnit"] as? [String: Any] {
                plain[code] = unit["value"] as? String ?? ""
                states.append(unit["state"] as? String ?? "")
            }
            guard let variations = localization["variations"] as? [String: Any],
                  let forms = variations["plural"] as? [String: Any] else { continue }
            var byForm: [String: String] = [:]
            for (form, rawForm) in forms {
                let unit = (rawForm as? [String: Any])?["stringUnit"] as? [String: Any]
                byForm[form] = unit?["value"] as? String ?? ""
                states.append(unit?["state"] as? String ?? "")
            }
            plural[code] = byForm
        }
        return Entry(key: key, plain: plain, plural: plural, states: states)
    }
}
