// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The setup cover: the model's walk, one step at a time, under the system
/// toolbar's Back, title, step and Skip. Skip and Bind end the walk in the
/// model and lower the cover through the navigation, landing on Controllers.
struct SetupCover: View {
    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        if let walk = model.setup {
            let chrome = setupChromeState(walk)
            NavigationStack {
                step(walk, setupInputs(localNetwork: model.localNetwork.status))
                    .scrollContentBackground(.hidden)
                    .background(DishTheme.background)
                    .modifier(SetupTitles(title: chrome.title, subtitle: chrome.subtitle))
                    .toolbar { toolbar(chrome) }
            }
        }
    }

    @ViewBuilder
    private func step(_ walk: SetupState, _ inputs: SetupInputs) -> some View {
        switch walk.step {
        case .welcome: WelcomeStep(state: welcomeStepState())
        case .input: InputStep(state: inputStepState(inputs))
        case .localNetworkPrimer: LocalNetworkStep(state: localNetworkStepState())
        case .pickPC: PickPCStep(state: pickPCStepState(inputs))
        case .review: ReviewStep(state: reviewStepState(walk.draft, inputs), bind: bind)
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
