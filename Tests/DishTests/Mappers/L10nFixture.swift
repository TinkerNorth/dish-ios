// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
@testable import Dish

/// The app's words in one language: that language's compiled table from
/// the package's catalog, with its locale.
enum L10nFixture {
    static func language(_ code: String) -> L10n {
        let catalog = L10n.app.catalog.bundle
        let table = catalog.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
        return L10n(catalog: StringCatalog(bundle: table ?? catalog, locale: Locale(identifier: code)))
    }
}
