// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Every word the app shows, by screen. Views read `L10n.app`; a test builds
/// one over a single language's tables. A key is its English text, written
/// as a C format string, so `LocalizationTests` can match it against the
/// catalog verbatim.
struct L10n {
    let catalog: StringCatalog

    static let app = L10n(catalog: StringCatalog(bundle: .module))

    /// The product name, never translated.
    let appName = "Dish"
}

/// What joins the parts of a row's second line ("Streaming · 3 pads · 4 ms");
/// not a word. Each part is its own key, so a count's plural switches on
/// that count alone.
let lineSeparator = " · "

/// A paragraph the catalog keeps one sentence to a key, so every key fits
/// on one line; the translations split at the same sentences.
func paragraph(_ sentences: String...) -> String {
    sentences.joined(separator: " ")
}
