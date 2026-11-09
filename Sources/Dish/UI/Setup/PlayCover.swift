// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The play cover: the screen the navigation asked for, over the on-screen
/// controller, in landscape (the scene turns the window), dark, with the
/// status bar and the system's overlays hidden and its edge gestures held
/// back so a swipe never leaves a game. The way out is the pause menu.
struct PlayCover: View {
    let screen: PlayScreen

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        PlayCoverBody(state: playCoverState(facts: model.shellFacts, screen: screen), actions: actions)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .defersSystemGestures(on: .all)
            .environment(\.colorScheme, .dark)
    }

    private var actions: PlayActions {
        PlayActions(
            pad: { model.onScreenPad($0) },
            touch: { model.onScreenTouch($0) },
            open: { navigation.send(.openPlay($0)) },
            setRumble: { model.setPlayRumble($0) },
            setMotion: { model.setPlayMotion($0) },
            setEmulateAs: { model.setPlayEmulateAs($0) },
            stop: stop
        )
    }

    /// Stop gamepad closes the cover and takes the controller off the list.
    private func stop() {
        navigation.send(.closePlay)
        model.stopOnScreenGamepad()
    }
}

/// The cover over its state, so a preview can draw every screen.
struct PlayCoverBody: View {
    let state: PlayCoverState
    let actions: PlayActions

    var body: some View {
        screen
            .padding(.horizontal, DishSpace.page)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DishTheme.background.ignoresSafeArea())
    }

    @ViewBuilder private var screen: some View {
        switch state.screen {
        case .gamepad: GamepadCover(state: state, actions: actions)
        case .touchpad: TouchpadCover(state: state, actions: actions)
        case .mouse: MouseCover(state: state, actions: actions)
        }
    }
}

#Preview("Pause menu", traits: .landscapeLeft) {
    PlayCoverBody(state: playCoverState(facts: FactsPreview.playing(.gamepad, emulateAs: .dualSense), screen: .gamepad), actions: .preview)
        .environment(\.colorScheme, .dark)
}
