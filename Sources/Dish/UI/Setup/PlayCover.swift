// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The play cover: the screen the navigation asked for, over the on-screen
/// controller, on its side on an iPhone (the scene turns the window) and
/// the way an iPad is held, dark, with the status bar and the system's
/// overlays hidden and its edge gestures held back so a swipe never leaves
/// a game. The way out is the pause menu.
struct PlayCover: View {
    let screen: PlayScreen

    @Environment(AppModel.self) private var model
    @Environment(NavigationStore.self) private var navigation
    @Environment(\.windowFacts) private var window

    var body: some View {
        PlayCoverBody(state: playCoverState(facts: model.shellFacts, screen: screen, window: window), actions: actions)
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

    /// The gamepad fills the window on its side and stands in its band along
    /// the bottom of an upright one; the touchpad and the mouse fill it
    /// either way.
    @ViewBuilder private var screen: some View {
        switch state.screen {
        case .gamepad:
            GamepadCover(state: state, actions: actions)
                .frame(maxHeight: state.pad.band)
                .frame(maxHeight: .infinity, alignment: .bottom)
        case .touchpad: TouchpadCover(state: state, actions: actions)
        case .mouse: MouseCover(state: state, actions: actions)
        }
    }
}

#Preview("Pause menu", traits: .landscapeLeft) {
    let facts = FactsPreview.playing(.gamepad, emulateAs: .dualSense)
    PlayCoverBody(state: playCoverState(facts: facts, screen: .gamepad, window: PreviewWindow.phoneOnItsSide), actions: .preview)
        .environment(\.colorScheme, .dark)
}
