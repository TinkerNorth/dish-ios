// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The bundled controller database is checked byte for byte against its
/// manifest's SHA-256 digests, so git must never rewrite its line endings.
final class ControllerDbDataTests: XCTestCase {

    func testTheBundledDatabaseIsNeverLineEndingNormalised() throws {
        let attributes = try RepoFiles.read(".gitattributes").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertTrue(attributes.contains("Sources/DishCore/Resources/controllers-v1/** -text"), ".gitattributes marks the data -text")
    }
}
