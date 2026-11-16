// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// What stands beside a line: a dot in the state's colour, or the spinner
/// of something under way.
enum StatusMark: Equatable {
    case dot(Color)
    case busy
}

/// The mark drawn: the dot, or the smallest spinner.
struct StatusMarkView: View {
    let mark: StatusMark

    var body: some View {
        switch mark {
        case let .dot(color): StatusDot(color: color)
        case .busy: ProgressView().controlSize(.mini)
        }
    }
}
