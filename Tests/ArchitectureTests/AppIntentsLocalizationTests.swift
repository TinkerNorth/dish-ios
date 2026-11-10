// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest

/// The words App Intents shows outside the app. Siri, Spotlight and the
/// Shortcuts app read them from the app bundle's own tables, never from the
/// package's catalog, so they live in the app target: every intent's title,
/// description and parameter, the PC's type name and every App Shortcut's
/// short title in `App/Resources/Localizable.xcstrings`, and every App
/// Shortcut phrase in `App/Resources/AppShortcuts.xcstrings`. Each is
/// translated into every language with its placeholders, and nothing in
/// either catalog goes unused.
final class AppIntentsLocalizationTests: XCTestCase {

    private static let languages: Set = ["bs", "de", "es", "fr", "pt-BR"]
    private static let wordsCatalog = "App/Resources/Localizable.xcstrings"
    private static let phrasesCatalog = "App/Resources/AppShortcuts.xcstrings"
    private static let intentSources = ["Sources/Dish/Intents", "App/Sources"]

    /// A Swift string literal's body.
    private static let literal = #""((?:[^"\\]|\\.)*)""#

    /// Where App Intents extracts a word: a title, a description, a
    /// parameter's title, a type's name, a short title, a summary.
    private static let wordPatterns = [
        #"LocalizedStringResource = "#,
        #"IntentDescription\("#,
        #"@Parameter\(title: "#,
        #"TypeDisplayRepresentation = "#,
        #"shortTitle: "#,
        #"Summary\("#
    ].map { $0 + literal }

    /// An App Shortcut phrase: a literal that names the app.
    private static let phrasePattern = #""((?:[^"\\]|\\.)*\\\(\.applicationName\)(?:[^"\\]|\\.)*)""#

    private var words: Set<String> = []
    private var phrases: Set<String> = []
    private var wordEntries: StringCatalogFile?
    private var phraseEntries: StringCatalogFile?

    override func setUpWithError() throws {
        let sources = try Self.intentSources.flatMap(RepoFiles.swiftFiles(under:)).map(RepoFiles.read)
        words = try Set(sources.flatMap { source in try Self.wordPatterns.flatMap { try Self.literals(in: source, pattern: $0) } })
        phrases = try Set(sources.flatMap { try Self.literals(in: $0, pattern: Self.phrasePattern) })
        wordEntries = try? StringCatalogFile(Self.wordsCatalog)
        phraseEntries = try? StringCatalogFile(Self.phrasesCatalog)
    }

    /// The key App Intents files each match under: an interpolated
    /// parameter or the app's name becomes `${name}`.
    private static func literals(in source: String, pattern: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        return matches.compactMap { match in Range(match.range(at: 1), in: source).map { key(String(source[$0])) } }
    }

    private static func key(_ literal: String) -> String {
        literal.replacingOccurrences(of: #"\\\((?:\\\.\$|\.)(\w+)\)"#, with: "\\${$1}", options: .regularExpression)
    }

    /// The `${…}` placeholders and format specifiers of a string, in order.
    private static func placeholders(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\$\{\w+\}|%(?:%|@|lld|.)"#) else { return ["<bad regex>"] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    // MARK: - The intents and the catalogs agree

    func testTheSweepSeesTheIntentsAndTheShortcuts() {
        XCTAssertGreaterThan(words.count, 10, "the sweep must see every intent and short title")
        XCTAssertGreaterThanOrEqual(phrases.count, 5, "the sweep must see a phrase per App Shortcut")
        XCTAssertTrue(phrases.allSatisfy { $0.contains("${applicationName}") })
    }

    func testEveryWordAnIntentShowsIsInTheAppsCatalogAndNothingElse() throws {
        let catalog = try XCTUnwrap(wordEntries, "\(Self.wordsCatalog) is missing")
        XCTAssertEqual(catalog.sourceLanguage, "en")
        XCTAssertEqual(words.subtracting(catalog.keys).sorted(), [], "words the app's catalog lacks")
        XCTAssertEqual(catalog.keys.subtracting(words).sorted(), [], "entries no intent or shortcut uses")
    }

    func testEveryPhraseIsInTheAppShortcutsCatalogAndNothingElse() throws {
        let catalog = try XCTUnwrap(phraseEntries, "\(Self.phrasesCatalog) is missing")
        XCTAssertEqual(catalog.sourceLanguage, "en")
        XCTAssertEqual(phrases.subtracting(catalog.keys).sorted(), [], "phrases the App Shortcuts catalog lacks")
        XCTAssertEqual(catalog.keys.subtracting(phrases).sorted(), [], "entries no App Shortcut uses")
    }

    // MARK: - Every entry, every language

    func testEveryEntryIsTranslatedIntoEveryLanguageWithItsPlaceholders() throws {
        let entries = try XCTUnwrap(wordEntries).entries + XCTUnwrap(phraseEntries).entries
        for entry in entries {
            XCTAssertEqual(Self.languages.subtracting(entry.languages).sorted(), [], "\(entry.key) lacks languages")
            XCTAssertEqual(Set(entry.states), ["translated"], entry.key)
            XCTAssertEqual(entry.plural, [:], "\(entry.key): App Intents' words take no plural forms")
            for (code, value) in entry.plain {
                XCTAssertFalse(value.isEmpty, "\(entry.key) is blank in \(code)")
                XCTAssertEqual(Self.placeholders(in: value), Self.placeholders(in: entry.key), "\(entry.key) in \(code)")
            }
        }
    }
}
