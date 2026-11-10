// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The clipboard as a seam: the scene hands the model the system's, so a
/// Copy button calls an intent and no view reaches for `UIPasteboard`.
@MainActor
package protocol Pasteboard: AnyObject {
    func copy(_ text: String)
}

/// A pasteboard that copies nothing: a model built outside the scene, in a
/// test or a preview.
@MainActor
package final class InertPasteboard: Pasteboard {
    package init() {}

    package func copy(_: String) {}
}

/// A pasteboard that keeps what it was asked to copy, for the tests.
@MainActor
package final class RecordedPasteboard: Pasteboard {
    package private(set) var copies: [String] = []

    package init() {}

    package func copy(_ text: String) {
        copies.append(text)
    }
}
