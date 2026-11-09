// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// What Support Dish's buttons do.
struct SupportActions {
    let tip: @MainActor (TipTier) -> Void
    let restore: @MainActor () -> Void
    let retry: @MainActor () -> Void
}

/// Support Dish, from the Controllers tab's heart and Settings › About:
/// tips through the App Store, which unlock nothing.
struct SupportPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SupportPageBody(
            state: supportPageState(support: model.shellFacts.support),
            actions: SupportActions(tip: tip, restore: restore, retry: retry)
        )
        .onAppear { model.pageAppeared(.support) }
        .onDisappear { model.pageDisappeared(.support) }
    }

    private func tip(_ tier: TipTier) {
        model.tip(tier)
    }

    private func restore() {
        model.restoreTips()
    }

    private func retry() {
        model.loadTips()
    }
}

/// The page over its state, so a preview can draw every state.
struct SupportPageBody: View {
    let state: SupportPageState
    let actions: SupportActions

    var body: some View {
        List {
            Section {
                SupportHero(heartSymbol: state.heartSymbol, title: state.title, pitch: state.pitch)
            }
            .listRowBackground(EmptyView())
            Section {
                SupportShelf(shelf: state.shelf, actions: actions)
            } header: {
                SectionEyebrow(title: state.tipsTitle, color: DishTheme.muted)
            }
            .listRowBackground(DishTheme.surface)
            SupportNotice(notice: state.notice)
            Section {
                Button(state.restoreTitle, action: actions.restore)
                    .disabled(!state.restoreEnabled)
            } footer: {
                SettingsFooter(text: state.footnote)
            }
            .listRowBackground(DishTheme.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The heart, the name and what a tip pays for.
private struct SupportHero: View {
    let heartSymbol: String
    let title: String
    let pitch: String

    var body: some View {
        VStack(spacing: DishSpace.s6) {
            Image(systemName: heartSymbol)
                .font(DishFont.largeTitle)
                .imageScale(.large)
                .foregroundStyle(DishTheme.pulse)
                .accessibilityHidden(true)
            Text(title).font(DishFont.title).foregroundStyle(DishTheme.onSurface)
            Text(pitch)
                .font(DishFont.body)
                .foregroundStyle(DishTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DishSpace.s8)
    }
}

/// The TIPS rows: loading, the three tips, or the App Store's refusal.
private struct SupportShelf: View {
    let shelf: SupportShelfState
    let actions: SupportActions

    var body: some View {
        switch shelf {
        case let .loading(text):
            HStack(spacing: DishSpace.s6) {
                ProgressView()
                Text(text).font(DishFont.body).foregroundStyle(DishTheme.muted)
            }
        case let .tips(buttons):
            ForEach(buttons) { TipRow(state: $0, tip: actions.tip) }
        case let .unavailable(message, retry):
            Text(message).font(DishFont.body).foregroundStyle(DishTheme.muted)
            Button(retry, action: actions.retry)
        }
    }
}

/// One tip: its name, and its price or the wait for the App Store.
private struct TipRow: View {
    let state: TipButtonState
    let tip: @MainActor (TipTier) -> Void

    var body: some View {
        Button { tip(state.tier) } label: {
            HStack {
                Text(state.title).font(DishFont.body).foregroundStyle(DishTheme.onSurface)
                Spacer()
                if state.busy {
                    ProgressView()
                } else {
                    Text(state.price).font(DishFont.headline).foregroundStyle(DishTheme.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(!state.enabled)
    }
}

/// The thank-you after a tip, or a note on how the last one went.
private struct SupportNotice: View {
    let notice: SupportNoticeState

    var body: some View {
        switch notice {
        case .none:
            EmptyView()
        case let .thanks(title, body):
            Section {
                Label {
                    VStack(alignment: .leading, spacing: DishSpace.s2) {
                        Text(title).font(DishFont.headline).foregroundStyle(DishTheme.onSurface)
                        Text(body).font(DishFont.detail).foregroundStyle(DishTheme.muted)
                    }
                } icon: {
                    Image(systemName: heartSymbol).foregroundStyle(DishTheme.pulse)
                }
            }
            .listRowBackground(DishTheme.surface)
        case let .note(text, color):
            Section {
                Text(text).font(DishFont.body).foregroundStyle(color)
            }
            .listRowBackground(DishTheme.surface)
        }
    }
}

#Preview("Tips") {
    let shelf = TipShelf.ready([
        TipProduct(tier: .small, displayPrice: "$0.99"),
        TipProduct(tier: .medium, displayPrice: "$4.99"),
        TipProduct(tier: .large, displayPrice: "$9.99")
    ])
    NavigationStack {
        SupportPageBody(
            state: supportPageState(support: SupportFacts(shelf: shelf, moment: .thanked)),
            actions: SupportActions(tip: { _ in }, restore: {}, retry: {})
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        SupportPageBody(state: supportPageState(support: .initial), actions: SupportActions(tip: { _ in }, restore: {}, retry: {}))
    }
}

#Preview("Unavailable") {
    NavigationStack {
        SupportPageBody(
            state: supportPageState(support: SupportFacts(shelf: .unavailable, moment: .failed)),
            actions: SupportActions(tip: { _ in }, restore: {}, retry: {})
        )
    }
}
