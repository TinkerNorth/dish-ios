// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// Add a PC by address, from the Connections toolbar and the setup cover:
/// one field for the host or host:port, the default port named under it,
/// and Connect, which reaches for the PC and then pairs. The draft and
/// whether it was refused are the sheet's own; the attempt's failure is the
/// model's word.
struct AddByAddressSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation
    @State private var draft = ""
    @State private var rejected = false
    @State private var connecting = false

    var body: some View {
        AddByAddressSheetBody(
            state: addByAddressSheetState(draft: draft, rejected: rejected, connecting: connecting, lastEvent: model.lastConnectionEvent),
            draft: $draft,
            connect: connect,
            cancel: cancel
        )
        .onAppear { model.pageAppeared(.addByAddress) }
        .onDisappear { model.pageDisappeared(.addByAddress) }
    }

    private func connect() {
        let accepted = model.addByAddress(draft)
        rejected = !accepted
        connecting = accepted
    }

    private func cancel() {
        navigation.send(.closeSheet)
    }
}

/// The sheet over its state, so a preview can draw every state.
struct AddByAddressSheetBody: View {
    let state: AddByAddressSheetState
    @Binding var draft: String
    let connect: @MainActor () -> Void
    let cancel: @MainActor () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(state.placeholder, text: $draft)
                        .font(DishFont.mono)
                        .foregroundStyle(DishTheme.onSurface)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit(connect)
                } header: {
                    Text(state.prompt).font(DishFont.detail).textCase(nil)
                } footer: {
                    AddressNotes(footnote: state.footnote, error: state.error)
                }
                .listRowBackground(DishTheme.surface)
                Section {
                    Button(action: connect) {
                        HStack(spacing: DishSpace.s4) {
                            if state.connecting {
                                ProgressView().controlSize(.small)
                            }
                            Text(state.connect).font(DishFont.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!state.connectEnabled)
                }
                .listRowBackground(DishTheme.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DishTheme.background)
            .navigationTitle(state.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(state.cancel, action: cancel)
                }
            }
        }
    }
}

/// The default port, and what went wrong under it.
private struct AddressNotes: View {
    let footnote: String
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s3) {
            Text(footnote).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            if let error {
                Text(error).font(DishFont.detail).foregroundStyle(DishTheme.error)
            }
        }
    }
}

#Preview("Empty") {
    @Previewable @State var draft = ""
    AddByAddressSheetBody(
        state: addByAddressSheetState(draft: draft, rejected: false, connecting: false, lastEvent: nil),
        draft: $draft,
        connect: {},
        cancel: {}
    )
}

#Preview("Refused") {
    @Previewable @State var draft = "den.local"
    AddByAddressSheetBody(
        state: addByAddressSheetState(draft: draft, rejected: true, connecting: false, lastEvent: nil),
        draft: $draft,
        connect: {},
        cancel: {}
    )
}
