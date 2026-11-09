// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// What a chip calls out: the recommended choice, or a fast one.
enum ChipTone: Equatable {
    case success
    case primary

    var foreground: Color {
        switch self {
        case .success: DishTheme.success
        case .primary: DishTheme.primary
        }
    }

    var fill: Color {
        switch self {
        case .success: DishTheme.successFill
        case .primary: DishTheme.primaryFill
        }
    }
}

/// A small tracked capsule beside a row's title or a section's eyebrow:
/// BEST, FASTEST, FAST.
struct Chip: View {
    let text: String
    let tone: ChipTone

    var body: some View {
        Text(text)
            .textCase(.uppercase)
            .font(DishFont.eyebrow)
            .tracking(DishSize.eyebrowTracking)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, DishSpace.s3)
            .padding(.vertical, DishSpace.s1)
            .background(tone.fill, in: Capsule())
    }
}

#Preview {
    HStack {
        Chip(text: L10n.app.setupBest, tone: .success)
        Chip(text: L10n.app.setupFast, tone: .primary)
    }
}
