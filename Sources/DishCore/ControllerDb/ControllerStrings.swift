// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The database's words: one flat table per locale (`strings/<locale>.json`),
// `en` complete and every other locale free to leave a key out, which then
// reads in English. Proper nouns, the controllers' names, live in `en` alone.

import Foundation

package struct ControllerStrings: Equatable {
    package static let fallbackLocale = "en"
    /// The locales the fleet ships, in the manifest's order.
    package static let locales = ["en", "bs", "de", "es", "fr", "pt-BR"]

    /// Locale to key to text.
    package let tables: [String: [String: String]]

    package init(tables: [String: [String: String]]) {
        self.tables = tables
    }

    /// The text for `key` in `locale`: the locale's own table, else the table
    /// of its language ("de-AT" reads "de", "pt" reads "pt-BR"), else `en`.
    package func text(_ key: String, locale: String) -> String? {
        let own = table(for: locale)?[key]
        return own ?? tables[Self.fallbackLocale]?[key]
    }

    package func controllerName(_ id: String, locale: String) -> String? {
        text("controller.\(id).name", locale: locale)
    }

    package func issueTitle(_ id: String, locale: String) -> String? {
        text("issue.\(id).title", locale: locale)
    }

    package func issueBody(_ id: String, locale: String) -> String? {
        text("issue.\(id).body", locale: locale)
    }

    private func table(for locale: String) -> [String: String]? {
        if let exact = tables[locale] {
            return exact
        }
        let language = languageOf(locale)
        let sameLanguage = tables.keys.sorted().first { languageOf($0) == language }
        return sameLanguage.flatMap { tables[$0] }
    }
}

/// "pt-BR" and "pt_BR" are "pt".
private func languageOf(_ locale: String) -> String {
    let separators = CharacterSet(charactersIn: "-_")
    let language = locale.components(separatedBy: separators).first ?? locale
    return language.lowercased()
}

/// One strings file: a flat object of string to string; a value that is not
/// a string, or anything but an object, refuses the file.
package func decodeControllerStrings(_ data: Data) -> Result<[String: String], ControllerDbError> {
    guard let table = try? JSONDecoder().decode([String: String].self, from: data) else { return .failure(.badJson) }
    return .success(table)
}
