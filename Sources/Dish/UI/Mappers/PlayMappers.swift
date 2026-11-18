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
    let mark: StatusMark
    let detailColor: Color
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

/// C4: its glyph and eyebrow, Left, the Scroll strip, Right, and the move
/// pad's hint.
struct MouseCoverState: Equatable {
    let symbol: String
    let eyebrow: String
    let left: String
    let scroll: String
    let right: String
    let hint: String
}

/// The touchpad: its glyph and eyebrow, a plain surface and its two click
/// zones.
struct TouchpadCoverState: Equatable {
    let symbol: String
    let eyebrow: String
    let click: String
    let hint: String
}

/// The gamepad's measures: a stick's base and thumb, the click stick's
/// beside it (L3, R3), a face button, a d-pad arm, a trigger rail and the
/// touchpad.
struct PadMetrics: Equatable {
    let stick: CGFloat
    let stickThumb: CGFloat
    let clickStick: CGFloat
    let clickStickThumb: CGFloat
    let face: CGFloat
    let dpadKey: CGFloat
    let rail: CGFloat
    let trackpad: CGSize

    /// The touchpad's two click zones: half a stick tall.
    var clickZone: CGFloat {
        stick / 2
    }

    /// The phone's, from the boards.
    static let compact = PadMetrics(
        stick: DishSize.padStick,
        stickThumb: DishSize.padStickThumb,
        clickStick: DishSize.padClickStick,
        clickStickThumb: DishSize.padClickStickThumb,
        face: DishSize.padFace,
        dpadKey: DishSize.padDpadKey,
        rail: DishSize.padRail,
        trackpad: CGSize(width: DishSize.padTrackpadWidth, height: DishSize.padTrackpadHeight)
    )

    /// An iPad's on its side, which has the room both ways.
    static let regular = PadMetrics(
        stick: DishSize.padStickRegular,
        stickThumb: DishSize.padStickThumbRegular,
        clickStick: DishSize.padClickStickRegular,
        clickStickThumb: DishSize.padClickStickThumbRegular,
        face: DishSize.padFaceRegular,
        dpadKey: DishSize.padDpadKeyRegular,
        rail: DishSize.padRailRegular,
        trackpad: CGSize(width: DishSize.padTrackpadWidthRegular, height: DishSize.padTrackpadHeightRegular)
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
    /// The way out, named for VoiceOver.
    let back: String
    /// The gamepad carries the emulated pad's touchpad.
    let trackpad: Bool
    let gamepad: GamepadCoverState
    let mouse: MouseCoverState
    let touchpad: TouchpadCoverState
    /// How the gamepad stands in the window the scene read.
    let pad: PadLayout
}

/// The SF Symbols the play screens, their rows and the gamepad's centre draw.
enum PlaySymbol {
    static let emulate = "chevron.up.chevron.down"
    static let touchpad = "rectangle.and.hand.point.up.left"
    static let mouse = "computermouse"
    static let view = "rectangle.on.rectangle"
    static let guide = "gamecontroller"
    static let menu = "line.3.horizontal"
    static let scrollUp = "chevron.up"
    static let scrollDown = "chevron.down"
}

/// The whole, for a test or a preview that holds one.
func playCoverState(facts: ShellFacts, screen: PlayScreen, window: WindowFacts, words: L10n = .app) -> PlayCoverState {
    playCoverState(play: facts.play, session: facts.session, screen: screen, window: window, words: words)
}

func playCoverState(
    play: PlayFacts?,
    session: SessionFact?,
    lowPower: LowPowerFact = .idle,
    screen: PlayScreen,
    window: WindowFacts,
    words: L10n = .app
) -> PlayCoverState {
    let emulateAs = play?.emulateAs ?? InputKind.onScreen.defaultEmulation
    return PlayCoverState(
        screen: screen,
        pill: playPill(session, destination: play?.destination, lowPower: lowPower, words: words),
        back: words.back,
        trackpad: emulateAs.hasTouchpad,
        gamepad: gamepadCoverState(emulateAs),
        mouse: MouseCoverState(
            symbol: PlaySymbol.mouse,
            eyebrow: words.mouse,
            left: words.mouseLeft,
            scroll: words.scroll,
            right: words.mouseRight,
            hint: words.mouseHint
        ),
        touchpad: TouchpadCoverState(
            symbol: PlaySymbol.touchpad,
            eyebrow: words.carriesTouchpad,
            click: words.click,
            hint: words.touchpadHint
        ),
        pad: padLayout(window)
    )
}

/// "Living Room PC" and its latency, or the low-power countdown's last
/// seconds; a PC that stopped answering or is being reached for says so.
/// `destination` is the served slot's PC, which speaks while no session is
/// up.
func playPill(
    _ session: SessionFact?,
    destination: DestinationFact? = nil,
    lowPower: LowPowerFact = .idle,
    words: L10n = .app
) -> PlayPillState? {
    guard let session else { return destinationPill(destination, words: words) }
    switch session.phase {
    case .streaming:
        let latency = session.latencyMs.map(words.latency) ?? words.streaming
        let detail = lowPower.countdown.map(words.lowPowerIn) ?? latency
        return PlayPillState(pcName: session.pcName, detail: detail, mark: .dot(DishTheme.success), detailColor: DishTheme.success)
    case .stoppedResponding:
        return PlayPillState(
            pcName: session.pcName,
            detail: words.stoppedResponding,
            mark: .dot(DishTheme.error),
            detailColor: DishTheme.error
        )
    case .reconnecting:
        return PlayPillState(pcName: session.pcName, detail: words.connecting, mark: .busy, detailColor: DishTheme.muted)
    case .failed:
        return PlayPillState(
            pcName: session.pcName,
            detail: words.connectionLost,
            mark: .dot(DishTheme.error),
            detailColor: DishTheme.error
        )
    }
}

/// The served slot's PC with no session up: answering, being reached for,
/// or lost, so the screen never goes quiet without a word.
private func destinationPill(_ destination: DestinationFact?, words: L10n) -> PlayPillState? {
    guard let destination else { return nil }
    switch destination.health {
    case .online:
        return PlayPillState(pcName: destination.name, detail: words.online, mark: .dot(DishTheme.success), detailColor: DishTheme.success)
    case .connecting:
        return PlayPillState(pcName: destination.name, detail: words.connecting, mark: .busy, detailColor: DishTheme.muted)
    case .lost:
        return PlayPillState(
            pcName: destination.name,
            detail: words.connectionLost,
            mark: .dot(DishTheme.error),
            detailColor: DishTheme.error
        )
    }
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
    case .touchpad: PlaySymbol.touchpad
    case .mouse: PlaySymbol.mouse
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

/// L3's or R3's finger: the stick's button pressed as the stick tilts with
/// it, as one press on a real stick does both; its lift lets go of both.
func clickStickEvents(_ stick: PadStick, _ offset: CGVector?) -> [OnScreenPadEvent] {
    let button = thumbButton(stick)
    guard let offset else { return [.stickReleased(stick), .release(button)] }
    return [.press(button), stickMove(stick, offset)]
}

/// The stick's own button: L3 or R3.
func thumbButton(_ stick: PadStick) -> WireButton {
    switch stick {
    case .left: .leftThumb
    case .right: .rightThumb
    }
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
