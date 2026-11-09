// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import Observation
import SwiftUI

/// The navigation machine at the app layer: it applies events, runs the
/// effects the machine returns (the welcome's completion persists; the
/// model's setup walk starts and ends), and hands `TabView`, each
/// `NavigationStack` and the `fullScreenCover` their bindings. On a first run
/// it raises the setup cover before anything is drawn, and starts the walk.
@MainActor
@Observable
final class NavigationStore {

    private(set) var state: NavigationState

    @ObservationIgnored private let onboarding: OnboardingPreferenceStore
    @ObservationIgnored private let startSetup: (SetupEntry) -> Void
    @ObservationIgnored private let endSetup: () -> Void

    init(onboarding: OnboardingPreferenceStore, startSetup: @escaping (SetupEntry) -> Void, endSetup: @escaping () -> Void) {
        self.onboarding = onboarding
        self.startSetup = startSetup
        self.endSetup = endSetup
        let firstRun = !onboarding.state.welcomeCompleted
        state = NavigationState(cover: firstRun ? .setup(.firstRun) : nil)
        if firstRun { startSetup(.firstRun) }
    }

    func send(_ event: NavigationEvent) {
        let step = reduceNavigation(state, event)
        state = step.state
        step.effects.forEach(run)
    }

    private func run(_ effect: NavigationEffect) {
        switch effect {
        case .markWelcomeComplete: onboarding.markWelcomeComplete()
        case let .startSetup(entry): startSetup(entry)
        case .endSetup: endSetup()
        }
    }

    /// The tab bar's selection; a tap on the tab on screen is a `select` too.
    var tab: Binding<Tab> {
        Binding(get: { self.state.tab }, set: { self.send(.select($0)) })
    }

    /// A tab's stack; a pop the stack makes itself is a `pathChanged` event.
    func path(of tab: Tab) -> Binding<[Page]> {
        Binding(get: { self.state.path(of: tab) }, set: { self.send(.pathChanged(tab, $0)) })
    }

    /// The cover on screen; a dismissal the system makes is `coverDismissed`.
    var cover: Binding<Cover?> {
        Binding(get: { self.state.cover }, set: { self.coverChanged($0) })
    }

    private func coverChanged(_ cover: Cover?) {
        if cover == nil, state.cover != nil { send(.coverDismissed) }
    }
}
