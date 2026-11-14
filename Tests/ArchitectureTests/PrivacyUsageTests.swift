// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest

/// iOS terminates an app that touches a privacy-sensitive framework without
/// the Info.plist key that words its question, so each framework the engine
/// imports for one has its key, and every question is worded in each of the
/// six languages in the app target's `InfoPlist.xcstrings`.
final class PrivacyUsageTests: XCTestCase {

    /// Each framework that asks the person, and the key that words its question.
    private static let questions = ["CoreBluetooth": "NSBluetoothAlwaysUsageDescription"]
    private static let languages = ["bs", "de", "en", "es", "fr", "pt-BR"]

    private func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: RepoFiles.url("App/Info.plist"))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func catalog() throws -> [String: Any] {
        let data = try Data(contentsOf: RepoFiles.url("App/Resources/InfoPlist.xcstrings"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(root["strings"] as? [String: Any])
    }

    private func importedModules() throws -> Set<String> {
        let files = RepoFiles.swiftFiles(under: "Sources")
        return try Set(files.flatMap { try RepoFiles.imports(of: RepoFiles.read($0)) })
    }

    private func value(_ localization: Any?) -> String? {
        let unit = (localization as? [String: Any])?["stringUnit"] as? [String: Any]
        guard unit?["state"] as? String == "translated" else { return nil }
        return unit?["value"] as? String
    }

    func testEveryFrameworkThatAsksThePersonHasItsQuestionInTheInfoPlist() throws {
        let plist = try infoPlist()
        let imported = try importedModules()
        XCTAssertTrue(imported.contains("CoreBluetooth"), "the Steam Controllers' radio")
        for (framework, key) in Self.questions where imported.contains(framework) {
            let question = plist[key] as? String
            XCTAssertFalse(question?.isEmpty ?? true, "\(framework) is imported, so App/Info.plist words \(key)")
        }
    }

    func testEveryQuestionIsWordedInEveryLanguage() throws {
        let plist = try infoPlist()
        let strings = try catalog()
        let keys = plist.keys.filter { $0.hasSuffix("UsageDescription") }
        XCTAssertEqual(Set(keys), ["NSLocalNetworkUsageDescription", "NSBluetoothAlwaysUsageDescription"])
        for key in keys {
            let localizations = (strings[key] as? [String: Any])?["localizations"] as? [String: Any]
            for language in Self.languages {
                XCTAssertNotNil(value(localizations?[language]), "\(key) in \(language)")
            }
            XCTAssertEqual(value(localizations?["en"]), plist[key] as? String, "\(key): the catalog's English is the Info.plist's")
        }
    }
}
