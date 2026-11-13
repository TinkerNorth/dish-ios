// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The PC the play screens send to, over every screen: its name and the
/// round trip, beside a dot for how the link is doing.
struct PlayPillState: Equatable {
    let pcName: String
    let detail: String
    let dot: Color
    let detailColor: Color
}

/// A play screen the pause menu moves to.
struct PauseScreenItem: Equatable, Identifiable {
    let screen: PlayScreen
    let title: String
    let symbol: String

    var id: PlayScreen {
        screen
    }
}

/// One switch of the pause menu: on or off, and when it cannot be on, why.
struct PauseToggleState: Equatable {
    let title: String
    let symbol: String
    let isOn: Bool
    let enabled: Bool
    /// Nil while the switch can be flipped.
    let reason: String?
}

/// The gamepad's switches: Motion, Rumble and Emulate as.
struct PauseSwitchesState: Equatable {
    let motion: PauseToggleState
    let rumble: PauseToggleState
    let emulateTitle: String
    let emulateSymbol: String
    let emulateAs: EmulatedPad
    let emulateOptions: [EmulateOption]
}

/// C3, the pause menu: Resume, the other screens, the gamepad's switches,
/// and Stop gamepad, the one way out.
struct PauseMenuState: Equatable {
    let title: String
    let resume: String
    let screens: [PauseScreenItem]
    /// Nil on the touchpad and the mouse, which have none.
    let switches: PauseSwitchesState?
    let stop: String
    /// TipKit's hint on the pause button: Stop gamepad is the way out.
    let hint: HintState
}

/// What a face button shows: a letter, or a PlayStation glyph.
enum FaceGlyph: Equatable {
    case letter(String)
    case symbol(String)
}

/// A face button, by the button it presses.
struct FaceButtonState: Equatable {
    let button: WireButton
    let glyph: FaceGlyph
    let tint: Color
}

/// C2's labels for the pad it emulates: the shoulders, the rails, the four
/// faces by position, and the thumbs.
struct GamepadCoverState: Equatable {
    let leftShoulder: String
    let rightShoulder: String
    let leftTrigger: String
    let rightTrigger: String
    let top: FaceButtonState
    let left: FaceButtonState
    let right: FaceButtonState
    let bottom: FaceButtonState
    let leftThumb: String
    let rightThumb: String
}

/// C4: Left, the Scroll strip, Right, and the move pad's hint.
struct MouseCoverState: Equatable {
    let eyebrow: String
    let left: String
    let scroll: String
    let right: String
    let hint: String
}

/// The touchpad: a plain surface and its two click zones.
struct TouchpadCoverState: Equatable {
    let eyebrow: String
    let click: String
    let hint: String
}

/// The gamepad's measures: a stick's base and thumb, a face button, a d-pad
/// arm and a trigger rail.
struct PadMetrics: Equatable {
    let stick: CGFloat
    let stickThumb: CGFloat
    let face: CGFloat
    let dpadKey: CGFloat
    let rail: CGFloat

    /// The touchpad's two click zones: half a stick tall.
    var clickZone: CGFloat {
        stick / 2
    }

    /// The phone's, from the boards.
    static let compact = PadMetrics(
        stick: DishSize.padStick,
        stickThumb: DishSize.padStickThumb,
        face: DishSize.padFace,
        dpadKey: DishSize.padDpadKey,
        rail: DishSize.padRail
    )

    /// An iPad's on its side, which has the room both ways.
    static let regular = PadMetrics(
        stick: DishSize.padStickRegular,
        stickThumb: DishSize.padStickThumbRegular,
        face: DishSize.padFaceRegular,
        dpadKey: DishSize.padDpadKeyRegular,
        rail: DishSize.padRailRegular
    )
}

/// How the gamepad stands in its window: its measures, and the band along
/// the bottom it keeps its landscape arrangement in when the window is
/// upright.
struct PadLayout: Equatable {
    let metrics: PadMetrics
    /// The band's height; nil fills the window.
    let band: CGFloat?
}

/// On its side the gamepad fills the window, larger where both size classes
/// are regular (an iPad; a Pro Max on its side is compact down). Upright,
/// which iPadOS leaves an iPad's play cover, it keeps its landscape
/// arrangement in a band along the bottom, at the phone's measures.
func padLayout(_ window: WindowFacts) -> PadLayout {
    switch window.shape {
    case .landscape: PadLayout(metrics: landscapeMetrics(window), band: nil)
    case .portrait: PadLayout(metrics: .compact, band: DishSize.padUprightHeight)
    }
}

private func landscapeMetrics(_ window: WindowFacts) -> PadMetrics {
    switch (window.width, window.height) {
    case (.regular, .regular): .regular
    case (.compact, _), (_, .compact): .compact
    }
}

/// Everything a play cover draws, whichever screen is up.
struct PlayCoverState: Equatable {
    let screen: PlayScreen
    /// Nil while no session is up.
    let pill: PlayPillState?
    let pause: PauseMenuState
    let gamepad: GamepadCoverState
    let mouse: MouseCoverState
    let touchpad: TouchpadCoverState
    /// How the gamepad stands in the window the scene read.
    let pad: PadLayout
}

/// The SF Symbols the pause menu and the gamepad's centre draw.
enum PlaySymbol {
    static let pause = "pause.fill"
    static let resume = "play.fill"
    static let motion = "gyroscope"
    static let rumble = "iphone.radiowaves.left.and.right"
    static let emulate = "chevron.up.chevron.down"
    static let stop = "stop.fill"
    static let view = "rectangle.on.rectangle"
    static let guide = "gamecontroller"
    static let menu = "line.3.horizontal"
    static let scrollUp = "chevron.up"
    static let scrollDown = "chevron.down"
}

func playCoverState(facts: ShellFacts, screen: PlayScreen, window: WindowFacts, words: L10n = .app) -> PlayCoverState {
    let emulateAs = facts.play?.emulateAs ?? InputKind.onScreen.defaultEmulation
    return PlayCoverState(
        screen: screen,
        pill: playPill(facts.session, words: words),
        pause: pauseMenuState(play: facts.play, screen: screen, words: words),
        gamepad: gamepadCoverState(emulateAs),
        mouse: MouseCoverState(
            eyebrow: words.mouse,
            left: words.mouseLeft,
            scroll: words.scroll,
            right: words.mouseRight,
            hint: words.mouseHint
        ),
        touchpad: TouchpadCoverState(eyebrow: words.carriesTouchpad, click: words.click, hint: words.touchpadHint),
        pad: padLayout(window)
    )
}

/// "Living Room PC" and its latency; a PC that stopped answering says so.
func playPill(_ session: SessionFact?, words: L10n = .app) -> PlayPillState? {
    guard let session else { return nil }
    switch session.phase {
    case .streaming:
        let detail = session.latencyMs.map(words.latency) ?? words.streaming
        return PlayPillState(pcName: session.pcName, detail: detail, dot: DishTheme.success, detailColor: DishTheme.success)
    case .stoppedResponding:
        return PlayPillState(pcName: session.pcName, detail: words.stoppedResponding, dot: DishTheme.error, detailColor: DishTheme.error)
    }
}

func pauseMenuState(play: PlayFacts?, screen: PlayScreen, words: L10n = .app) -> PauseMenuState {
    PauseMenuState(
        title: words.pause,
        resume: words.resume,
        screens: PlayScreen.allCases.filter { $0 != screen }.map { pauseScreenItem($0, words: words) },
        switches: pauseSwitches(play: play, screen: screen, words: words),
        stop: words.stopGamepad,
        hint: hintState(.stopGamepad, words: words)
    )
}

func playScreenTitle(_ screen: PlayScreen, words: L10n = .app) -> String {
    switch screen {
    case .gamepad: words.gamepad
    case .touchpad: words.carriesTouchpad
    case .mouse: words.mouse
    }
}

func playScreenSymbol(_ screen: PlayScreen) -> String {
    switch screen {
    case .gamepad: "gamecontroller"
    case .touchpad: "rectangle.and.hand.point.up.left"
    case .mouse: "cursorarrow"
    }
}

private func pauseScreenItem(_ screen: PlayScreen, words: L10n) -> PauseScreenItem {
    PauseScreenItem(screen: screen, title: playScreenTitle(screen, words: words), symbol: playScreenSymbol(screen))
}

/// The gamepad alone carries Motion, Rumble and Emulate as.
private func pauseSwitches(play: PlayFacts?, screen: PlayScreen, words: L10n) -> PauseSwitchesState? {
    guard screen == .gamepad, let play else { return nil }
    return PauseSwitchesState(
        motion: motionToggle(play, words: words),
        rumble: PauseToggleState(title: words.carriesRumble, symbol: PlaySymbol.rumble, isOn: play.rumble, enabled: true, reason: nil),
        emulateTitle: words.setupEmulateAs,
        emulateSymbol: PlaySymbol.emulate,
        emulateAs: play.emulateAs,
        emulateOptions: EmulatedPad.allCases.map { EmulateOption(pad: $0, name: emulatedPadName($0, words: words)) }
    )
}

/// Motion is disabled with its reason while the emulated pad or the phone
/// has none, and reads off then whatever the switch holds.
private func motionToggle(_ play: PlayFacts, words: L10n) -> PauseToggleState {
    let reason = motionReason(play.motionAvailability, words: words)
    let available = reason == nil
    return PauseToggleState(
        title: words.setupMotion,
        symbol: PlaySymbol.motion,
        isOn: available && play.motion,
        enabled: available,
        reason: reason
    )
}

func motionReason(_ availability: PlayMotion, words: L10n = .app) -> String? {
    switch availability {
    case .available: nil
    case .padHasNone: words.motionNeedsDualSense
    case .phoneHasNone: words.motionNeedsSensors
    }
}

// MARK: - The gamepad's labels

/// The faces by position, as each family names and colours them: the
/// button at the bottom is XUSB's A whatever it is called.
func gamepadCoverState(_ pad: EmulatedPad) -> GamepadCoverState {
    switch pad {
    case .xboxWireless: xboxLabels
    case .dualSense, .dualShock4, .dualSenseEdge: playStationLabels
    case .switchPro: switchLabels
    }
}

private let xboxLabels = GamepadCoverState(
    leftShoulder: "LB",
    rightShoulder: "RB",
    leftTrigger: "LT",
    rightTrigger: "RT",
    top: FaceButtonState(button: .faceY, glyph: .letter("Y"), tint: DishTheme.padYellow),
    left: FaceButtonState(button: .faceX, glyph: .letter("X"), tint: DishTheme.padBlue),
    right: FaceButtonState(button: .faceB, glyph: .letter("B"), tint: DishTheme.padRed),
    bottom: FaceButtonState(button: .faceA, glyph: .letter("A"), tint: DishTheme.padGreen),
    leftThumb: "L3",
    rightThumb: "R3"
)

private let playStationLabels = GamepadCoverState(
    leftShoulder: "L1",
    rightShoulder: "R1",
    leftTrigger: "L2",
    rightTrigger: "R2",
    top: FaceButtonState(button: .faceY, glyph: .symbol("triangle"), tint: DishTheme.padGreen),
    left: FaceButtonState(button: .faceX, glyph: .symbol("square"), tint: DishTheme.padPink),
    right: FaceButtonState(button: .faceB, glyph: .symbol("circle"), tint: DishTheme.padRed),
    bottom: FaceButtonState(button: .faceA, glyph: .symbol("xmark"), tint: DishTheme.padBlue),
    leftThumb: "L3",
    rightThumb: "R3"
)

private let switchLabels = GamepadCoverState(
    leftShoulder: "L",
    rightShoulder: "R",
    leftTrigger: "ZL",
    rightTrigger: "ZR",
    top: FaceButtonState(button: .faceY, glyph: .letter("X"), tint: DishTheme.onSurface),
    left: FaceButtonState(button: .faceX, glyph: .letter("Y"), tint: DishTheme.onSurface),
    right: FaceButtonState(button: .faceB, glyph: .letter("A"), tint: DishTheme.onSurface),
    bottom: FaceButtonState(button: .faceA, glyph: .letter("B"), tint: DishTheme.onSurface),
    leftThumb: "L3",
    rightThumb: "R3"
)

// MARK: - From a control's touch to the reducer's event

/// A button held or let go.
func padHold(_ button: WireButton, held: Bool) -> OnScreenPadEvent {
    held ? .press(button) : .release(button)
}

/// A stick's finger, in radii from its centre with y down, or its lift.
func stickMove(_ stick: PadStick, _ offset: CGVector?) -> OnScreenPadEvent {
    guard let offset else { return .stickReleased(stick) }
    return .stick(stick, x: Float(offset.dx), y: Float(offset.dy))
}

/// A rail's finger, 0 at its top and 1 at its bottom, or its lift.
func railPull(_ trigger: PadTrigger, _ railY: Double?) -> OnScreenPadEvent {
    guard let railY else { return .triggerReleased(trigger) }
    return .trigger(trigger, railY: Float(railY))
}

/// The d-pad's finger, in arm lengths from its centre, or its lift.
func dpadMove(_ offset: CGVector?) -> OnScreenPadEvent {
    guard let offset else { return .dpadReleased }
    return .dpad(x: Float(offset.dx), y: Float(offset.dy))
}

/// A finger on a touch surface, by the slot the surface gave it, or its lift.
func fingerMove(_ slot: Int, _ point: CGPoint?) -> TouchSurfaceEvent {
    let touchSlot: TouchSlot = slot == 0 ? .first : .second
    guard let point else { return .lifted(touchSlot) }
    return .finger(touchSlot, x: Float(point.x), y: Float(point.y))
}
