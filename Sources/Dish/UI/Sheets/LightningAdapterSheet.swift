// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// Wired on this iPhone, from the Lightning note on the Controllers tab and
/// on setup's Input step: the phone, the adapter and the pad in a row, why
/// a Lightning cable alone will not do, the steps, the Bluetooth aside and
/// Apple's page for the adapter. Done lowers it through the navigation.
struct LightningAdapterSheet: View {
    @Environment(NavigationStore.self) private var navigation
    @Environment(\.openURL) private var openURL

    var body: some View {
        LightningAdapterSheetBody(state: lightningAdapterSheetState(), open: open, done: done)
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }

    private func done() {
        navigation.send(.closeSheet)
    }
}

/// The sheet over its state, so a preview can draw it.
struct LightningAdapterSheetBody: View {
    let state: LightningAdapterSheetState
    let open: @MainActor (URL?) -> Void
    let done: @MainActor () -> Void

    var body: some View {
        NavigationStack {
            List {
                AdapterIllustration(thisIPhone: state.thisIPhone, adapter: state.adapterLabel, controller: state.controller)
                AdapterHeading(title: state.headline, detail: state.body)
                Section {
                    ForEach(state.steps) { step in
                        HStack(spacing: DishSpace.s6) {
                            SetupGlyphTile(symbol: step.symbol)
                            Text(step.text)
                                .font(DishFont.body)
                                .foregroundStyle(DishTheme.onSurface)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    SectionEyebrow(title: state.stepsTitle, color: DishTheme.muted)
                } footer: {
                    Text(state.note)
                        .font(DishFont.detail)
                        .foregroundStyle(DishTheme.muted)
                }
                .listRowBackground(DishTheme.surface)
                Section {
                    Button { open(state.adapterLink.url) } label: { ExternalLinkRow(title: state.adapterLink.title) }
                }
                .listRowBackground(DishTheme.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DishTheme.background)
            .navigationTitle(state.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(state.done, action: done)
                }
            }
        }
    }
}

/// The phone, the adapter between, and the controller.
private struct AdapterIllustration: View {
    let thisIPhone: AdapterTile
    let adapter: String
    let controller: AdapterTile

    var body: some View {
        HStack(alignment: .top, spacing: DishSpace.s8) {
            IllustrationTile(symbol: thisIPhone.symbol, label: thisIPhone.label)
            VStack(spacing: DishSpace.s4) {
                DishImage.adapter
                    .resizable()
                    .scaledToFit()
                    .frame(height: DishSize.adapterArt)
                    .frame(height: DishSize.primerTile)
                    .foregroundStyle(DishTheme.primary)
                SectionEyebrow(title: adapter, color: DishTheme.muted)
            }
            IllustrationTile(symbol: controller.symbol, label: controller.label)
        }
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityHidden(true)
    }
}

/// The sheet's one sentence and the line under it, at the head of its list.
private struct AdapterHeading: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s3) {
            Text(title)
                .font(DishFont.title)
                .foregroundStyle(DishTheme.onSurface)
            Text(detail)
                .font(DishFont.body)
                .foregroundStyle(DishTheme.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: DishSpace.s4, leading: DishSpace.s2, bottom: DishSpace.s4, trailing: DishSpace.s2))
    }
}

#Preview("Wired on this iPhone") {
    LightningAdapterSheetBody(state: lightningAdapterSheetState(), open: { _ in }, done: {})
}
