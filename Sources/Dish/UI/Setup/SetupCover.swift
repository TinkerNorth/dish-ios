// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The setup cover: the model's walk, one step at a time, under the system
/// toolbar's Back, title, step and Skip, and the sheets Pick your PC opens
/// over it, in a readable column on an iPad. Skip and Bind end the walk in
/// the model and lower the cover through the navigation, landing on
/// Controllers.
struct SetupCover: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation
    @Environment(\.windowFacts) private var window

    var body: some View {
        let cover = setupCoverState(facts: model.shellFacts, width: window.width)
        if let cover {
            NavigationStack {
                step(cover.step)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: cover.column)
                    .frame(maxWidth: .infinity)
                    .background(DishTheme.background)
                    .modifier(SetupTitles(title: cover.chrome.title, subtitle: cover.chrome.subtitle))
                    .toolbar { toolbar(cover.chrome) }
            }
            .sheet(item: navigation.setupSheet) { ShellSheet(sheet: $0) }
        }
    }

    @ViewBuilder
    private func step(_ step: SetupStepState) -> some View {
        switch step {
        case let .welcome(state): WelcomeStep(state: state)
        case let .input(state): InputStep(state: state)
        case let .localNetwork(state): LocalNetworkStep(state: state)
        case let .pickPC(state): PickPCStep(state: state)
        case let .review(state): ReviewStep(state: state, bind: bind)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(_ chrome: SetupChromeState) -> some ToolbarContent {
        if chrome.showsBack {
            ToolbarItem(placement: .topBarLeading) {
                Button(chrome.back, systemImage: DishSymbol.back, action: model.setupBack)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(chrome.skip, action: skip)
        }
    }

    private func skip() {
        model.setupSkip()
        navigation.send(.setupEnded(.skipped))
    }

    private func bind() {
        model.bindSetup()
        navigation.send(.setupEnded(.bound))
    }
}

/// The inline title and the step under it; the welcome has neither.
private struct SetupTitles: ViewModifier {
    let title: String?
    let subtitle: String?

    func body(content: Content) -> some View {
        if let title, let subtitle {
            content
                .navigationTitle(title)
                .navigationSubtitle(subtitle)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}

#Preview("Welcome") {
    SetupCover()
        .environment(PreviewSetup.model(at: .welcome))
        .environment(PreviewSetup.navigation())
}

#Preview("Input") {
    SetupCover()
        .environment(PreviewSetup.model(at: .input))
        .environment(PreviewSetup.navigation())
}

#Preview("Local Network") {
    SetupCover()
        .environment(PreviewSetup.model(at: .localNetworkPrimer))
        .environment(PreviewSetup.navigation())
}

#Preview("Pick your PC") {
    SetupCover()
        .environment(PreviewSetup.model(at: .pickPC))
        .environment(PreviewSetup.navigation())
}

#Preview("Review") {
    SetupCover()
        .environment(PreviewSetup.model(at: .review))
        .environment(PreviewSetup.navigation())
}

#Preview("Welcome, iPad on its side", traits: .landscapeLeft) {
    SetupCover()
        .environment(PreviewSetup.model(at: .welcome))
        .environment(PreviewSetup.navigation())
        .environment(\.windowFacts, PreviewWindow.iPadOnItsSide)
}

#Preview("Input, iPad upright", traits: .portrait) {
    SetupCover()
        .environment(PreviewSetup.model(at: .input))
        .environment(PreviewSetup.navigation())
        .environment(\.windowFacts, PreviewWindow.iPadUpright)
}
