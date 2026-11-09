// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Settings › About and the licenses page.
extension L10n {

    var website: String {
        catalog.text("Website")
    }

    var sourceCode: String {
        catalog.text("Source code")
    }

    var openSourceLicenses: String {
        catalog.text("Open source licenses")
    }

    var noLicenseManifest: String {
        catalog.text("No license manifest")
    }

    var licenseManifestUnreadable: String {
        catalog.text("The bundled acknowledgements could not be read from this build.")
    }

    func aboutLine(_ version: String) -> String {
        catalog.format("Dish %@ · TinkerNorth · LGPL-3.0", version)
    }

    var lgplNotice: String {
        paragraph(
            catalog.text("Dish is free software, licensed under the GNU Lesser General Public License, version 3 or later."),
            catalog.text("It comes with no warranty, to the extent permitted by law.")
        )
    }
}
