// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI
import TipKit

/// TipKit's tip over a hint's state: its words and its glyph. TipKit keeps,
/// under the hint's name, whether it was shown, closed or put to rest; an
/// urgent hint shows even on a day another one has.
struct HintTip: Tip {
    let state: HintState

    var id: String {
        state.id
    }

    var title: Text {
        Text(state.title)
    }

    var message: Text? {
        Text(state.message)
    }

    var image: Image? {
        Image(systemName: state.symbol)
    }

    var options: [any TipOption] {
        Tips.IgnoresDisplayFrequency(state.urgent)
    }
}

extension View {
    /// TipKit's popover for the hint, pointing at this control while TipKit
    /// says it is due; nil points at nothing.
    func hint(_ state: HintState?) -> some View {
        popoverTip(state.map(HintTip.init))
    }
}
