// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// Settings › Name on your PC.
struct DeviceNamePage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        DeviceNamePageBody(state: deviceNamePageState(preferences: model.shellFacts.preferences), save: model.setDeviceName)
    }
}

/// The name field. Its draft is the page's own, starting at the stored name,
/// and is saved on Return and when the page goes away.
struct DeviceNamePageBody: View {
    let state: DeviceNamePageState
    let save: @MainActor (String) -> Void

    @State private var draft: String

    init(state: DeviceNamePageState, save: @escaping @MainActor (String) -> Void) {
        self.state = state
        self.save = save
        _draft = State(initialValue: state.draft)
    }

    var body: some View {
        List {
            Section {
                TextField(state.placeholder, text: $draft)
                    .font(DishFont.body)
                    .foregroundStyle(DishTheme.onSurface)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(commit)
            } footer: {
                SettingsFooter(text: state.footer)
            }
            .listRowBackground(DishTheme.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: commit)
    }

    private func commit() {
        save(draft)
    }
}

#Preview("Name on your PC") {
    let preferences = PreferencesFacts(deviceName: "Den iPhone", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system)
    NavigationStack {
        DeviceNamePageBody(state: deviceNamePageState(preferences: preferences), save: { _ in })
    }
}
