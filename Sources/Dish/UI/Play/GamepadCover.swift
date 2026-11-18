// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// C2, the on-screen gamepad: the rails down both sides, the shoulders,
/// the way out and the PC along the top, the left stick and L3 over the
/// d-pad, the centre's touchpad when the emulated pad carries one over its
/// View, Guide and Menu, and the faces over R3 and the right stick. Each
/// control holds its own finger, at the measures the window has room for.
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

    /// The touchpad sits at the top centre, where a DualShock and a DualSense
    /// carry theirs; View, Guide and Menu keep the middle.
    private var centre: some View {
        VStack(spacing: DishSpace.s6) {
            if state.trackpad {
                Trackpad(size: metrics.trackpad, onFinger: { actions.touch(fingerMove($0, $1)) }, onTap: { actions.tap() })
            }
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
                corner
                face(state.top)
                corner
            }
            GridRow {
                face(state.left)
                Color.clear.frame(width: size, height: size).allowsHitTesting(false)
                face(state.right)
            }
            GridRow {
                corner
                face(state.bottom)
                corner
            }
        }
    }

    /// A cell that holds its place and takes no finger: the rows overlap by
    /// the diamond's tightening, and a face keeps its whole circle.
    private var corner: some View {
        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]).allowsHitTesting(false)
    }

    private func face(_ button: FaceButtonState) -> some View {
        FaceButton(state: button, size: size) { hold(button.button, $0) }
    }
}

/// Along the top of every play screen: what sits at its edges, the way out
/// and the PC the screen sends to.
struct PlayTopBar<Leading: View, Trailing: View>: View {
    let state: PlayCoverState
    let actions: PlayActions
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            leading()
            Spacer(minLength: DishSpace.s4)
            PlayBackButton(title: state.back, action: actions.stop)
            if let pill = state.pill {
                PlayPill(state: pill, symbol: satelliteSymbol)
                    .fixedSize()
            }
            Spacer(minLength: DishSpace.s4)
            trailing()
        }
    }
}

#Preview("Gamepad", traits: .landscapeLeft) {
    let facts = FactsPreview.playing(.gamepad, emulateAs: .dualSense)
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
