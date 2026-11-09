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

/// A paragraph the catalog keeps one sentence to a key, so every key fits
/// on one line; the translations split at the same sentences.
func paragraph(_ sentences: String...) -> String {
    sentences.joined(separator: " ")
}
