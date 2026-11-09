// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// Help & FAQ, pushed from Settings › Setup & help: the way into setup,
/// the questions folded under their sections, and the links.
struct HelpPage: View {
    @Environment(NavigationStore.self) private var navigation
    @Environment(\.openURL) private var openURL

    var body: some View {
        HelpPageBody(state: helpPageState(), walkThrough: walkThrough, open: open)
    }

    private func walkThrough() {
        navigation.send(.openSetup(.guide))
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }
}

/// The page over its state, so a preview can draw it.
struct HelpPageBody: View {
    let state: HelpPageState
    let walkThrough: @MainActor () -> Void
    let open: @MainActor (URL?) -> Void

    var body: some View {
        List {
            Section {
                Button(state.walkThrough, action: walkThrough)
            } footer: {
                SettingsFooter(text: state.subline)
            }
            .listRowBackground(DishTheme.surface)
            ForEach(state.sections) { section in
                Section {
                    ForEach(section.entries) { HelpEntryView(entry: $0) }
                } header: {
                    SectionEyebrow(title: section.title, color: DishTheme.muted)
                }
                .listRowBackground(DishTheme.surface)
            }
            Section {
                ForEach(state.links) { link in
                    Button { open(link.url) } label: { ExternalLinkRow(title: link.title) }
                }
            } header: {
                SectionEyebrow(title: state.linksTitle, color: DishTheme.muted)
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

/// One question, folded until it is opened.
private struct HelpEntryView: View {
    let entry: HelpEntryState

    var body: some View {
        DisclosureGroup {
            Text(entry.answer)
                .font(DishFont.detail)
                .foregroundStyle(DishTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Text(entry.question)
                .font(DishFont.body)
                .foregroundStyle(DishTheme.onSurface)
        }
        .tint(DishTheme.primary)
    }
}

#Preview("Help & FAQ") {
    NavigationStack {
        HelpPageBody(state: helpPageState(), walkThrough: {}, open: { _ in })
    }
}
