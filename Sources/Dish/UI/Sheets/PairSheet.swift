// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// What the pair sheet's controls do: a whole PIN is sent, Try again files
/// a new code, Rename changes the name the PC sees, Cancel closes the sheet.
struct PairActions {
    let submit: @MainActor (String) -> Void
    let tryAgain: @MainActor () -> Void
    let rename: @MainActor (String) -> Void
    let cancel: @MainActor () -> Void

    /// Controls that do nothing, for a preview.
    @MainActor static let preview = PairActions(submit: { _ in }, tryAgain: {}, rename: { _ in }, cancel: {})
}

/// B5, Pair with a PC: the PIN Satellite shows typed into its cells, and
/// the code to accept on the PC beside it, both at once; whichever lands
/// first pairs. The digits typed are the sheet's own; everything else is
/// the model's card.
struct PairSheet: View {
    let serverId: String

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation
    @State private var typed = ""

    var body: some View {
        PairSheetBody(
            state: pairSheetState(
                pairing: model.openPairing,
                serverId: serverId,
                deviceName: model.shellFacts.preferences.deviceName,
                typed: typed
            ),
            typed: $typed,
            actions: PairActions(submit: submit, tryAgain: tryAgain, rename: rename, cancel: cancel)
        )
    }

    private func submit(_ pin: String) {
        model.submitPin(serverId, pin: pin)
    }

    private func tryAgain() {
        model.newCode(serverId)
    }

    private func rename(_ name: String) {
        model.renameThisIPhone(serverId, to: name)
    }

    private func cancel() {
        navigation.send(.closeSheet)
    }
}

/// The sheet over its state, so a preview can draw every state.
struct PairSheetBody: View {
    let state: PairSheetState
    @Binding var typed: String
    let actions: PairActions

    var body: some View {
        NavigationStack {
            switch state {
            case let .card(card):
                PairCard(state: card, typed: $typed, actions: actions)
                    .background(DishTheme.background)
                    .navigationTitle(card.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(card.cancel, systemImage: DishSymbol.close, action: actions.cancel)
                        }
                    }
            case .ended:
                DishTheme.background.ignoresSafeArea()
            }
        }
    }
}

/// The card: the prompt, the cells with the field over them, the hint or
/// the error, "or", the request, and Rename this iPhone.
private struct PairCard: View {
    let state: PairCardState
    @Binding var typed: String
    let actions: PairActions

    @FocusState private var pinFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: DishSpace.s8) {
                Text(state.prompt)
                    .font(DishFont.body)
                    .foregroundStyle(DishTheme.muted)
                    .multilineTextAlignment(.center)
                typedPin
                PinNotes(hint: state.pinHint, error: state.pinError, submitting: state.submitting)
                OrRule(word: state.orWord)
                if let request = state.request {
                    PairRequestCard(state: request, tryAgain: actions.tryAgain)
                }
                RenameRow(
                    title: state.rename,
                    placeholder: state.renamePlaceholder,
                    name: state.deviceName,
                    done: state.done,
                    rename: actions.rename
                )
            }
            .padding(DishSpace.page)
        }
        .defaultFocus($pinFocused, true)
        .onChange(of: typed) { _, raw in typedChanged(raw) }
        .onChange(of: state.pinError) { _, error in rejected(error) }
    }

    /// The field lies over the cells and draws nothing of its own, no title
    /// and no placeholder: it owns the focus, the typing and the paste, and
    /// the cells render what it holds. Its ink and caret are clear rather
    /// than its opacity zero, so it still takes the tap; VoiceOver reads the
    /// prompt for it.
    private var typedPin: some View {
        ZStack {
            PinCells(cells: state.cells, stroke: state.cellStroke, focusStroke: DishTheme.primary, ink: DishTheme.onSurface)
            TextField("", text: $typed)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundStyle(.clear)
                .tint(.clear)
                .focused($pinFocused)
                .disabled(!state.fieldEnabled)
                .labelsHidden()
                .accessibilityLabel(state.prompt)
        }
        .frame(maxWidth: .infinity)
    }

    /// Only digits stay, as many as a PIN has; a whole PIN is sent at once.
    private func typedChanged(_ raw: String) {
        let digits = pinDigits(raw)
        if digits != raw { typed = digits }
        if isWholePin(digits) { actions.submit(digits) }
    }

    /// A refused PIN clears the cells for the next try.
    private func rejected(_ error: String?) {
        if error != nil { typed = "" }
    }
}

/// Where the PIN is on the PC, the spinner while one is on its way, and
/// why the last one was refused.
private struct PinNotes: View {
    let hint: String
    let error: String?
    let submitting: Bool

    var body: some View {
        VStack(spacing: DishSpace.s3) {
            HStack(spacing: DishSpace.s3) {
                if submitting {
                    ProgressView().controlSize(.small)
                }
                Text(hint).font(DishFont.monoDetail).foregroundStyle(DishTheme.muted)
            }
            if let error {
                Text(error)
                    .font(DishFont.detail)
                    .foregroundStyle(DishTheme.error)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// "or" between two rules.
private struct OrRule: View {
    let word: String

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            Divider().overlay(DishTheme.outline)
            Text(word).font(DishFont.detail).foregroundStyle(DishTheme.muted)
            Divider().overlay(DishTheme.outline)
        }
    }
}

/// Accept on your PC: the request Satellite shows, this iPhone's code, and
/// where the request stands, with Try again once it ended.
private struct PairRequestCard: View {
    let state: PairRequestState
    let tryAgain: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DishSpace.s6) {
            VStack(alignment: .leading, spacing: DishSpace.s3) {
                Text(state.title).font(DishFont.headline).foregroundStyle(DishTheme.onSurface)
                Text(state.body).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                HStack(spacing: DishSpace.s3) {
                    if state.waiting {
                        ProgressView().controlSize(.small)
                    }
                    Text(state.status).font(DishFont.detail).foregroundStyle(state.statusColor)
                }
                if let hint = state.hint {
                    Text(hint).font(DishFont.caption).foregroundStyle(DishTheme.muted)
                }
                if let retry = state.retry {
                    Button(retry, action: tryAgain)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .font(DishFont.detail)
                }
            }
            Spacer(minLength: DishSpace.s4)
            Text(state.code)
                .font(DishFont.clientPin)
                .monospacedDigit()
                .tracking(DishSize.clientPinTracking)
                .foregroundStyle(DishTheme.primary)
        }
        .padding(DishSpace.s8)
        .background(RoundedRectangle(cornerRadius: DishSize.cardCorner, style: .continuous).fill(DishTheme.surfaceDim))
        .accessibilityElement(children: .combine)
    }
}

/// Rename this iPhone: a link that opens the name field in place; Done
/// saves it, and the PC reads the new name.
private struct RenameRow: View {
    let title: String
    let placeholder: String
    let name: String
    let done: String
    let rename: @MainActor (String) -> Void

    @State private var renaming = false
    @State private var draft = ""

    var body: some View {
        if renaming {
            HStack(spacing: DishSpace.s4) {
                TextField(placeholder, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(commit)
                Button(done, action: commit)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            }
        } else {
            Button(title, action: begin)
                .font(DishFont.headline)
                .tint(DishTheme.primary)
        }
    }

    private func begin() {
        draft = name
        renaming = true
    }

    private func commit() {
        rename(draft)
        renaming = false
    }
}

#Preview("Waiting") {
    @Previewable @State var typed = "73"
    let server = DiscoveredServer(name: "Living Room PC", ip: "192.168.1.24", machineId: "lr")
    let attempt = PairingAttempt(clientPin: "4821", phase: .awaiting)
    PairSheetBody(
        state: pairSheetState(pairing: OpenPairing(server: server, attempt: attempt), serverId: "mid:lr", deviceName: "", typed: typed),
        typed: $typed,
        actions: .preview
    )
}

#Preview("Declined, PIN refused") {
    @Previewable @State var typed = ""
    let server = DiscoveredServer(name: "Living Room PC", ip: "192.168.1.24", machineId: "lr")
    let attempt = PairingAttempt(clientPin: "4821", phase: .declined, rejection: .wrongPin, rejections: 3)
    PairSheetBody(
        state: pairSheetState(
            pairing: OpenPairing(server: server, attempt: attempt),
            serverId: "mid:lr",
            deviceName: "Den iPhone",
            typed: typed
        ),
        typed: $typed,
        actions: .preview
    )
}
