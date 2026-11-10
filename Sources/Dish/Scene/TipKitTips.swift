// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import TipKit

/// TipKit behind the hints. The scene turns it on once, at most one hint a
/// day (the way out of play excepted), and the navigation tells it each
/// hint the person no longer needs, which puts that hint to rest. The UI
/// tests keep it off through the argument domain (`-tips_hidden YES`), so
/// no popover covers what they tap.
enum TipKitTips {
    /// The defaults key that keeps TipKit off.
    static let hiddenKey = "tips_hidden"

    static func configure(hidden: Bool) {
        guard !hidden else { return }
        // TipKit throws only when it was configured already; the hints work either way.
        _ = try? Tips.configure([.displayFrequency(.daily)])
    }

    static func learned(_ hint: Hint) {
        HintTip(state: hintState(hint)).invalidate(reason: .actionPerformed)
    }
}
