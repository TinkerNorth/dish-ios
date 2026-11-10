// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation

/// A tab: the root of its own navigation stack.
enum Tab: CaseIterable, Hashable {
    case controllers
    case connections
    case settings
}

/// A page pushed onto a tab's stack.
enum Page: Hashable {
    /// Settings › Name on your PC.
    case deviceName
    /// Controllers › a controller's own page, by its slot id.
    case controller(id: String)
    /// Settings › Setup & help › Help & FAQ.
    case help
    /// Settings › About › Open source licenses.
    case licenses
    /// Support Dish: the Controllers tab's heart, and Settings › About.
    case support
    /// Settings › Setup & help › Diagnostics.
    case diagnostics
}

/// Where the setup cover opens.
enum SetupEntry: Hashable {
    /// The first run: the welcome, then the three steps.
    case firstRun
    /// "Add a controller": straight to the first step.
    case addController
    /// Settings › Setup guide: the welcome again.
    case guide
}

/// A full-screen cover over the tabs.
enum Cover: Hashable {
    case setup(SetupEntry)
    /// A play screen, in landscape; the pause menu moves between them.
    case play(PlayScreen)
    /// The low-power dim while a pad is forwarded; a tap wakes it.
    case dim
}

enum NavigationEvent: Equatable {
    case select(Tab)
    /// Push onto the tab on screen.
    case push(Page)
    /// A tab's stack moved on its own: the back button, a swipe, a system pop.
    case pathChanged(Tab, [Page])
    case openSetup(SetupEntry)
    case setupEnded(SetupEnding)
    /// Open a play screen, or move to another from the pause menu.
    case openPlay(PlayScreen)
    /// The pause menu's way out.
    case closePlay
    /// The session accessory's Dim.
    case dim
    /// A tap on the dimmed screen.
    case wake
    /// The system lowered the cover (a swipe down, a scene change).
    case coverDismissed
}

enum NavigationEffect: Equatable {
    case markWelcomeComplete
    /// The model opens its setup walk at this entry.
    case startSetup(SetupEntry)
    /// The model drops its setup walk.
    case endSetup
    /// The model opens this play screen on the on-screen controller.
    case startPlay(PlayScreen)
    /// The model closes the play screen, releasing what it held.
    case endPlay
}

struct NavigationState: Equatable {
    var tab = Tab.controllers
    var paths: [Tab: [Page]] = [:]
    var cover: Cover?

    func path(of tab: Tab) -> [Page] {
        paths[tab] ?? []
    }
}

struct NavigationStep: Equatable {
    let state: NavigationState
    let effects: [NavigationEffect]
}

/// The shell's one navigation rule: each tab keeps its own stack, a tap on
/// the tab on screen unwinds it, a page pushes onto it, setup, play and the
/// dim cover everything, a cover replacing another ends it, and leaving
/// setup by any road lands on Controllers.
func reduceNavigation(_ state: NavigationState, _ event: NavigationEvent) -> NavigationStep {
    switch event {
    case let .select(tab): selected(state, tab)
    case let .push(page): pushed(state, page)
    case let .pathChanged(tab, path): pathMoved(state, tab, path)
    case let .openSetup(entry): setupOpened(state, entry)
    case let .setupEnded(ending): setupLeft(state, ending)
    case let .openPlay(screen): playOpened(state, screen)
    case .closePlay: playClosed(state)
    case .dim: dimmed(state)
    case .wake: woken(state)
    case .coverDismissed: coverLowered(state)
    }
}

/// A tap on the tab on screen pops it to its root, as iOS does.
private func selected(_ state: NavigationState, _ tab: Tab) -> NavigationStep {
    var next = state
    let reselected = state.tab == tab
    if reselected { next.paths[tab] = [] }
    next.tab = tab
    return NavigationStep(state: next, effects: [])
}

private func pushed(_ state: NavigationState, _ page: Page) -> NavigationStep {
    var next = state
    next.paths[state.tab] = state.path(of: state.tab) + [page]
    return NavigationStep(state: next, effects: [])
}

private func pathMoved(_ state: NavigationState, _ tab: Tab, _ path: [Page]) -> NavigationStep {
    var next = state
    next.paths[tab] = path
    return NavigationStep(state: next, effects: [])
}

private func covered(_ state: NavigationState, _ cover: Cover) -> NavigationStep {
    var next = state
    next.cover = cover
    return NavigationStep(state: next, effects: [])
}

/// Setup replaces whatever covered the tabs, the dim included, and the model
/// starts its walk at the entry asked for.
private func setupOpened(_ state: NavigationState, _ entry: SetupEntry) -> NavigationStep {
    let raised = covered(state, .setup(entry))
    return NavigationStep(state: raised.state, effects: ended(state.cover, by: .setup(entry)) + [.startSetup(entry)])
}

/// A play screen replaces whatever covered the tabs; from another play
/// screen it is the pause menu moving on, under the same cover.
private func playOpened(_ state: NavigationState, _ screen: PlayScreen) -> NavigationStep {
    let raised = covered(state, .play(screen))
    return NavigationStep(state: raised.state, effects: ended(state.cover, by: .play(screen)) + [.startPlay(screen)])
}

private func playClosed(_ state: NavigationState) -> NavigationStep {
    guard case .play = state.cover else { return NavigationStep(state: state, effects: []) }
    var next = state
    next.cover = nil
    return NavigationStep(state: next, effects: [.endPlay])
}

/// What the model must end when `next` replaces `cover`: a walk or a play
/// screen covered by something else. A cover of the same kind carries on.
private func ended(_ cover: Cover?, by next: Cover) -> [NavigationEffect] {
    switch (cover, next) {
    case (.setup, .setup), (.play, .play): []
    case (.setup, _): [.endSetup]
    case (.play, _): [.endPlay]
    case (.dim, _), (nil, _): []
    }
}

/// Both roads out of setup land on Controllers and complete the welcome, or
/// it would rise again on the next launch.
private func setupLeft(_ state: NavigationState, _ ending: SetupEnding) -> NavigationStep {
    guard case .setup = state.cover else { return NavigationStep(state: state, effects: []) }
    var next = state
    next.cover = nil
    next.tab = .controllers
    switch ending {
    case .bound, .skipped: return NavigationStep(state: next, effects: [.endSetup, .markWelcomeComplete])
    }
}

/// The dim rises only over the tabs: the accessory that asks for it is not
/// on screen under a cover, a play screen included.
private func dimmed(_ state: NavigationState) -> NavigationStep {
    guard state.cover == nil else { return NavigationStep(state: state, effects: []) }
    return covered(state, .dim)
}

private func woken(_ state: NavigationState) -> NavigationStep {
    guard state.cover == .dim else { return NavigationStep(state: state, effects: []) }
    var next = state
    next.cover = nil
    return NavigationStep(state: next, effects: [])
}

/// A cover the system lowered ends what it showed: setup as a skip, play
/// as a close, the dim as a wake.
private func coverLowered(_ state: NavigationState) -> NavigationStep {
    switch state.cover {
    case .setup: setupLeft(state, .skipped)
    case .dim: woken(state)
    case .play: playClosed(state)
    case nil: NavigationStep(state: state, effects: [])
    }
}
