// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import Observation
import SwiftUI

/// The navigation machine at the app layer: it applies events, runs the
/// effects the machine returns (the welcome's completion persists; the
/// model's setup walk, play screens and pairing start and end), and hands
/// `TabView`, each `NavigationStack`, the `fullScreenCover` and the sheets
/// their bindings. On a first run it raises the setup cover before anything
/// is drawn, and starts the walk.
@MainActor
@Observable
final class NavigationStore {

    private(set) var state: NavigationState

    @ObservationIgnored private let onboarding: OnboardingPreferenceStore
    @ObservationIgnored private let startSetup: (SetupEntry) -> Void
    @ObservationIgnored private let endSetup: () -> Void
    @ObservationIgnored private let startPlay: (PlayScreen) -> Void
    @ObservationIgnored private let endPlay: () -> Void
    @ObservationIgnored private let beginPairing: (String) -> Void
    @ObservationIgnored private let cancelPairing: (String) -> Void
    @ObservationIgnored private let connect: (String) -> Void
    @ObservationIgnored private let learned: (Hint) -> Void

    /// `learned` hears which hint the person no longer needs, so TipKit
    /// puts it to rest.
    init(
        onboarding: OnboardingPreferenceStore,
        startSetup: @escaping (SetupEntry) -> Void,
        endSetup: @escaping () -> Void,
        startPlay: @escaping (PlayScreen) -> Void = { _ in },
        endPlay: @escaping () -> Void = {},
        beginPairing: @escaping (String) -> Void = { _ in },
        cancelPairing: @escaping (String) -> Void = { _ in },
        connect: @escaping (String) -> Void = { _ in },
        learned: @escaping (Hint) -> Void = { _ in }
    ) {
        self.onboarding = onboarding
        self.startSetup = startSetup
        self.endSetup = endSetup
        self.startPlay = startPlay
        self.endPlay = endPlay
        self.beginPairing = beginPairing
        self.cancelPairing = cancelPairing
        self.connect = connect
        self.learned = learned
        let firstRun = !onboarding.state.welcomeCompleted
        state = NavigationState(cover: firstRun ? .setup(.firstRun) : nil)
        if firstRun { startSetup(.firstRun) }
    }

    func send(_ event: NavigationEvent) {
        let before = state
        let step = reduceNavigation(before, event)
        state = step.state
        step.effects.forEach(run)
        if let hint = learnedHint(event, from: before, to: step.state) { learned(hint) }
    }

    private func run(_ effect: NavigationEffect) {
        switch effect {
        case .markWelcomeComplete: onboarding.markWelcomeComplete()
        case let .startSetup(entry): startSetup(entry)
        case .endSetup: endSetup()
        case let .startPlay(screen): startPlay(screen)
        case .endPlay: endPlay()
        case let .beginPairing(serverId): beginPairing(serverId)
        case let .cancelPairing(serverId): cancelPairing(serverId)
        case let .connect(id): connect(id)
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

    /// A split tab's list selection: the page beside the list. A selected
    /// row is a `show`; a cleared selection closes the page.
    func listSelection(of tab: Tab) -> Binding<Page?> {
        Binding(get: { self.state.opened(in: tab) }, set: { self.listSelected($0, in: tab) })
    }

    /// A split tab's detail column: the pages pushed over the one its list
    /// opened. A pop there stops at that page.
    func detailPath(of tab: Tab) -> Binding<[Page]> {
        Binding(get: { Array(self.state.path(of: tab).dropFirst()) }, set: { self.detailMoved($0, in: tab) })
    }

    /// The cover on screen; a dismissal the system makes is `coverDismissed`.
    var cover: Binding<Cover?> {
        Binding(get: { self.state.cover }, set: { self.coverChanged($0) })
    }

    /// The sheet the tabs present while no cover is up; a swipe down closes it.
    var tabsSheet: Binding<Sheet?> {
        Binding(get: { presentedSheet(self.state, by: .tabs) }, set: { self.sheetChanged($0) })
    }

    /// The sheet the setup cover presents while it is up.
    var setupSheet: Binding<Sheet?> {
        Binding(get: { presentedSheet(self.state, by: .setup) }, set: { self.sheetChanged($0) })
    }

    private func coverChanged(_ cover: Cover?) {
        if cover == nil, state.cover != nil { send(.coverDismissed) }
    }

    private func listSelected(_ page: Page?, in tab: Tab) {
        switch page {
        case let page?: send(.show(page, in: tab))
        case nil: send(.pathChanged(tab, []))
        }
    }

    private func detailMoved(_ pages: [Page], in tab: Tab) {
        let opened = state.path(of: tab).prefix(1)
        send(.pathChanged(tab, Array(opened) + pages))
    }

    private func sheetChanged(_ sheet: Sheet?) {
        if sheet == nil, state.sheet != nil { send(.closeSheet) }
    }
}
