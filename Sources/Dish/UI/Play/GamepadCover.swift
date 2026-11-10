// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// C2, the on-screen gamepad: the rails down both sides, the shoulders,
/// the PC and the pause button along the top, the left stick and L3 over
/// the d-pad, the centre's View, Guide and Menu, and the faces over R3 and
/// the right stick. Each control holds its own finger, at the measures the
/// window has room for.
struct GamepadCover: View {
    let state: PlayCoverState
    let actions: PlayActions

    private var labels: GamepadCoverState {
        state.gamepad
    }

    private var metrics: PadMetrics {
        state.pad.metrics
    }

    var body: some View {
        HStack(alignment: .top, spacing: DishSpace.s12) {
            TriggerRail(title: labels.leftTrigger, breadth: metrics.rail) { actions.pad(railPull(.left, $0)) }
                .padding(.top, DishSize.padShoulderHeight + DishSpace.s8)
            VStack(spacing: DishSpace.s6) {
                PlayTopBar(state: state, actions: actions) {
                    ShoulderButton(title: labels.leftShoulder) { hold(.leftShoulder, $0) }
                } trailing: {
                    ShoulderButton(title: labels.rightShoulder) { hold(.rightShoulder, $0) }
                }
                HStack(alignment: .top, spacing: 0) {
                    leftHand
                    Spacer(minLength: DishSpace.s4)
                    centre
                    Spacer(minLength: DishSpace.s4)
                    rightHand
                }
            }
            TriggerRail(title: labels.rightTrigger, breadth: metrics.rail) { actions.pad(railPull(.right, $0)) }
                .padding(.top, DishSize.padShoulderHeight + DishSpace.s8)
        }
        .padding(.vertical, DishSpace.s6)
    }

    private var leftHand: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: DishSpace.s6) {
                PadStickControl(base: metrics.stick, thumb: metrics.stickThumb) { actions.pad(stickMove(.left, $0)) }
                RoundPadButton(face: .label(labels.leftThumb)) { hold(.leftThumb, $0) }
            }
            Spacer(minLength: 0)
            DirectionPad(key: metrics.dpadKey) { actions.pad(dpadMove($0)) }
                .padding(.leading, metrics.stick / 2)
        }
    }

    private var centre: some View {
        VStack {
            Spacer()
            HStack(spacing: DishSpace.s6) {
                RoundPadButton(face: .symbol(PlaySymbol.view)) { hold(.back, $0) }
                RoundPadButton(face: .symbol(PlaySymbol.guide)) { hold(.guide, $0) }
                RoundPadButton(face: .symbol(PlaySymbol.menu)) { hold(.start, $0) }
            }
            Spacer()
        }
    }

    private var rightHand: some View {
        VStack(alignment: .trailing, spacing: 0) {
            FaceDiamond(state: labels, size: metrics.face, hold: hold)
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: DishSpace.s6) {
                RoundPadButton(face: .label(labels.rightThumb)) { hold(.rightThumb, $0) }
                PadStickControl(base: metrics.stick, thumb: metrics.stickThumb) { actions.pad(stickMove(.right, $0)) }
            }
            .padding(.trailing, metrics.face)
        }
    }

    private func hold(_ button: WireButton, _ held: Bool) {
        actions.pad(padHold(button, held: held))
    }
}

/// The four faces in their diamond, each `size` across.
private struct FaceDiamond: View {
    let state: GamepadCoverState
    let size: CGFloat
    let hold: @MainActor (WireButton, Bool) -> Void

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: -DishSpace.s4) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                face(state.top)
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
            GridRow {
                face(state.left)
                Color.clear.frame(width: size, height: size)
                face(state.right)
            }
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                face(state.bottom)
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
        }
    }

    private func face(_ button: FaceButtonState) -> some View {
        FaceButton(state: button, size: size) { hold(button.button, $0) }
    }
}

/// Along the top of every play screen: what sits at its edges, the PC the
/// screen sends to, and the pause menu.
struct PlayTopBar<Leading: View, Trailing: View>: View {
    let state: PlayCoverState
    let actions: PlayActions
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            leading()
            Spacer(minLength: DishSpace.s4)
            if let pill = state.pill {
                PlayPill(state: pill, symbol: satelliteSymbol)
                    .fixedSize()
            }
            PauseMenu(state: state.pause, actions: actions)
            Spacer(minLength: DishSpace.s4)
            trailing()
        }
    }
}

#Preview("Gamepad", traits: .landscapeLeft) {
    let facts = FactsPreview.playing(.gamepad)
    GamepadCover(state: playCoverState(facts: facts, screen: .gamepad, window: PreviewWindow.phoneOnItsSide), actions: .preview)
        .background(DishTheme.background)
        .environment(\.colorScheme, .dark)
}

#Preview("Gamepad, iPad on its side", traits: .landscapeLeft) {
    let state = playCoverState(facts: FactsPreview.playing(.gamepad), screen: .gamepad, window: PreviewWindow.iPadOnItsSide)
    PlayCoverBody(state: state, actions: .preview)
        .environment(\.colorScheme, .dark)
}

#Preview("Gamepad, iPad upright", traits: .portrait) {
    let state = playCoverState(facts: FactsPreview.playing(.gamepad), screen: .gamepad, window: PreviewWindow.iPadUpright)
    PlayCoverBody(state: state, actions: .preview)
        .environment(\.colorScheme, .dark)
}
