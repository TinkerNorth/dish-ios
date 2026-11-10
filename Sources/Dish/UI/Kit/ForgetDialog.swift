// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// Forget This PC's question, which the PC's page and a Connections row
/// both ask before a PC goes: its title, what stops, the destructive
/// Forget and Cancel. With no state there is nothing to ask.
struct ForgetDialog: ViewModifier {
    let state: ForgetPcState?
    @Binding var isPresented: Bool
    let forget: @MainActor () -> Void

    func body(content: Content) -> some View {
        if let state {
            content.confirmationDialog(state.title, isPresented: $isPresented, titleVisibility: .visible) {
                Button(state.confirm, role: .destructive, action: forget)
                Button(state.cancel, role: .cancel) {}
            } message: {
                Text(state.message)
            }
        } else {
            content
        }
    }
}
