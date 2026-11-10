// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// What a sheet shows: the tabs and the setup cover each present the one
/// the navigation holds, through this switch.
struct ShellSheet: View {
    let sheet: Sheet

    var body: some View {
        switch sheet {
        case let .pair(serverId): PairSheet(serverId: serverId)
        case .addByAddress: AddByAddressSheet()
        }
    }
}

extension Sheet: Identifiable {
    var id: Sheet {
        self
    }
}
