// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The play screens (C2, C3, C4) and the touchpad: the PC pill, every
/// state of the pause menu, the gamepad's labels for each emulated pad,
/// and the words of the mouse and the touchpad.
final class PlayMappersTests: XCTestCase {

    private func cover(
        _ play: PlayFacts? = FactsFixture.play(),
        screen: PlayScreen = .gamepad,
        session: SessionFact? = nil,
        window: WindowFacts = WindowFixture.phoneOnItsSide
    ) -> PlayCoverState {
        playCoverState(facts: FactsFixture.shell(session: session, play: play), screen: screen, window: window)
    }

    private func switches(_ play: PlayFacts) throws -> PauseSwitchesState {
        try XCTUnwrap(cover(play).pause.switches)
    }

    // MARK: - The pill

    func testThePillNamesThePCAndItsLatencyInTheOnlineColour() {
        let pill = cover(session: FactsFixture.streaming()).pill
        XCTAssertEqual(
            pill,
            PlayPillState(pcName: "Living Room PC", detail: "4 ms", dot: DishTheme.success, detailColor: DishTheme.success)
        )
    }

    func testAPillWithNoLatencyYetSaysStreaming() {
        XCTAssertEqual(cover(session: FactsFixture.streaming(latencyMs: nil)).pill?.detail, "Streaming")
    }

    func testAPCThatStoppedAnsweringTurnsThePillToTheError() {
        let pill = cover(session: FactsFixture.stopped).pill
        XCTAssertEqual(pill?.detail, "Stopped responding")
        XCTAssertEqual(pill?.dot, DishTheme.error)
    }

    func testWithNoSessionThereIsNoPill() {
        XCTAssertNil(cover().pill)
    }

    // MARK: - The pause menu

    func testThePauseMenuResumesAndStops() {
        let pause = cover().pause
        XCTAssertEqual(pause.title, "Pause")
        XCTAssertEqual(pause.resume, "Resume")
        XCTAssertEqual(pause.stop, "Stop gamepad")
    }

    func testThePauseMenuOffersTheOtherTwoScreens() {
        XCTAssertEqual(cover(screen: .gamepad).pause.screens.map(\.title), ["Touchpad", "Mouse"])
        XCTAssertEqual(cover(screen: .touchpad).pause.screens.map(\.title), ["Gamepad", "Mouse"])
        XCTAssertEqual(cover(screen: .mouse).pause.screens.map(\.screen), [.gamepad, .touchpad])
        XCTAssertEqual(cover(screen: .mouse).pause.screens.map(\.symbol), ["gamecontroller", "rectangle.and.hand.point.up.left"])
    }

    func testOnlyTheGamepadHasSwitches() {
        XCTAssertNotNil(cover(screen: .gamepad).pause.switches)
        XCTAssertNil(cover(screen: .touchpad).pause.switches)
        XCTAssertNil(cover(screen: .mouse).pause.switches)
        XCTAssertNil(cover(nil).pause.switches, "no play facts yet, nothing to switch")
    }

    func testAnXboxPadDisablesMotionWithTheReason() throws {
        let motion = try switches(FactsFixture.play(emulateAs: .xboxWireless, motion: true, motionAvailability: .padHasNone)).motion
        XCTAssertEqual(motion.title, "Motion")
        XCTAssertFalse(motion.enabled)
        XCTAssertFalse(motion.isOn, "an unavailable switch reads off")
        XCTAssertEqual(motion.reason, "Needs DualSense emulation")
    }

    func testAPhoneWithoutSensorsDisablesMotionWithItsReason() throws {
        let motion = try switches(FactsFixture.play(emulateAs: .dualSense, motionAvailability: .phoneHasNone)).motion
        XCTAssertFalse(motion.enabled)
        XCTAssertEqual(motion.reason, "This iPhone has no motion sensors")
    }

    func testAMotionPadOffersTheSwitchAsItStands() throws {
        let on = try switches(FactsFixture.play(emulateAs: .dualSense, motion: true, motionAvailability: .available)).motion
        XCTAssertTrue(on.enabled)
        XCTAssertTrue(on.isOn)
        XCTAssertNil(on.reason)
        let off = try switches(FactsFixture.play(emulateAs: .dualSense, motion: false, motionAvailability: .available)).motion
        XCTAssertFalse(off.isOn)
    }

    func testRumbleIsAToggleThatReadsItsSwitch() throws {
        let on = try switches(FactsFixture.play(rumble: true)).rumble
        XCTAssertEqual(on, PauseToggleState(title: "Rumble", symbol: PlaySymbol.rumble, isOn: true, enabled: true, reason: nil))
        XCTAssertFalse(try switches(FactsFixture.play(rumble: false)).rumble.isOn)
    }

    func testEmulateAsOffersEveryPadAndSelectsThePick() throws {
        let state = try switches(FactsFixture.play(emulateAs: .switchPro))
        XCTAssertEqual(state.emulateTitle, "Emulate as")
        XCTAssertEqual(state.emulateAs, .switchPro)
        XCTAssertEqual(state.emulateOptions.map(\.name), ["DualSense", "DualShock 4", "Xbox Wireless", "Switch Pro", "DualSense Edge"])
    }

    // MARK: - The gamepad

    func testAnXboxPadDrawsItsLettersInItsColours() {
        let pad = cover(FactsFixture.play(emulateAs: .xboxWireless)).gamepad
        XCTAssertEqual([pad.leftShoulder, pad.rightShoulder, pad.leftTrigger, pad.rightTrigger], ["LB", "RB", "LT", "RT"])
        XCTAssertEqual(pad.bottom, FaceButtonState(button: .faceA, glyph: .letter("A"), tint: DishTheme.padGreen))
        XCTAssertEqual(pad.right.tint, DishTheme.padRed)
        XCTAssertEqual(pad.left.tint, DishTheme.padBlue)
        XCTAssertEqual(pad.top.glyph, .letter("Y"))
        XCTAssertEqual([pad.leftThumb, pad.rightThumb], ["L3", "R3"])
    }

    func testAPlayStationPadDrawsItsGlyphs() {
        for emulated in [EmulatedPad.dualSense, .dualShock4, .dualSenseEdge] {
            let pad = cover(FactsFixture.play(emulateAs: emulated)).gamepad
            XCTAssertEqual([pad.leftShoulder, pad.leftTrigger], ["L1", "L2"])
            XCTAssertEqual(pad.bottom.glyph, .symbol("xmark"))
            XCTAssertEqual(pad.top.glyph, .symbol("triangle"))
            XCTAssertEqual(pad.left.tint, DishTheme.padPink)
        }
    }

    func testASwitchProNamesItsButtonsWhereNintendoPutsThem() {
        let pad = cover(FactsFixture.play(emulateAs: .switchPro)).gamepad
        XCTAssertEqual([pad.leftTrigger, pad.rightTrigger], ["ZL", "ZR"])
        XCTAssertEqual(pad.bottom, FaceButtonState(button: .faceA, glyph: .letter("B"), tint: DishTheme.onSurface))
        XCTAssertEqual(pad.right.glyph, .letter("A"))
    }

    func testWithNoPlayFactsYetTheGamepadIsAnXboxPad() {
        XCTAssertEqual(cover(nil).gamepad.leftShoulder, "LB")
    }

    // MARK: - The mouse and the touchpad

    func testTheMouseWordsItsButtonsAndItsHint() {
        let mouse = cover(screen: .mouse).mouse
        XCTAssertEqual(
            mouse,
            MouseCoverState(eyebrow: "Mouse", left: "Left", scroll: "Scroll", right: "Right", hint: "Drag to move the pointer")
        )
    }

    func testTheTouchpadWordsItsClickZonesAndItsHint() {
        let touchpad = cover(screen: .touchpad).touchpad
        XCTAssertEqual(touchpad, TouchpadCoverState(eyebrow: "Touchpad", click: "Click", hint: "Use one or two fingers"))
    }

    func testTheCoverCarriesTheScreenItShows() {
        for screen in PlayScreen.allCases {
            XCTAssertEqual(cover(screen: screen).screen, screen)
        }
    }

    // MARK: - The room the window gives

    func testAPhoneOnItsSideKeepsThePhonesGamepad() {
        XCTAssertEqual(cover(window: WindowFixture.phoneOnItsSide).pad, PadLayout(metrics: .compact, band: nil))
        let phone = PadMetrics(
            stick: DishSize.padStick,
            stickThumb: DishSize.padStickThumb,
            face: DishSize.padFace,
            dpadKey: DishSize.padDpadKey,
            rail: DishSize.padRail
        )
        XCTAssertEqual(PadMetrics.compact, phone)
    }

    func testAnIPadOnItsSideGrowsTheSticksFacesRailsAndDpad() {
        XCTAssertEqual(cover(window: WindowFixture.iPadOnItsSide).pad, PadLayout(metrics: .regular, band: nil))
        let iPad = PadMetrics(
            stick: DishSize.padStickRegular,
            stickThumb: DishSize.padStickThumbRegular,
            face: DishSize.padFaceRegular,
            dpadKey: DishSize.padDpadKeyRegular,
            rail: DishSize.padRailRegular
        )
        XCTAssertEqual(PadMetrics.regular, iPad)
        XCTAssertGreaterThan(iPad.stick, DishSize.padStick)
        XCTAssertGreaterThan(iPad.face, DishSize.padFace)
        XCTAssertGreaterThan(iPad.dpadKey, DishSize.padDpadKey)
        XCTAssertGreaterThan(iPad.rail, DishSize.padRail)
    }

    func testAProMaxOnItsSideIsRegularAcrossButShortAndKeepsThePhonesGamepad() {
        XCTAssertEqual(cover(window: WindowFixture.proMaxOnItsSide).pad, PadLayout(metrics: .compact, band: nil))
    }

    /// iPadOS will not turn an upright iPad's window, so the gamepad keeps
    /// its landscape arrangement in a band along the bottom, where the hands
    /// hold it.
    func testAnUprightIPadStandsTheGamepadAlongTheBottom() {
        XCTAssertEqual(cover(window: WindowFixture.iPadUpright).pad, PadLayout(metrics: .compact, band: DishSize.padUprightHeight))
    }

    func testTheTouchpadsClickZonesAreHalfAStick() {
        XCTAssertEqual(PadMetrics.compact.clickZone, DishSize.padStick / 2)
        XCTAssertEqual(PadMetrics.regular.clickZone, DishSize.padStickRegular / 2)
    }
}

/// A control's touch becomes the reducer's event.
final class PlayEventMappersTests: XCTestCase {

    func testAHeldButtonPressesAndALiftReleases() {
        XCTAssertEqual(padHold(.faceA, held: true), .press(.faceA))
        XCTAssertEqual(padHold(.leftThumb, held: false), .release(.leftThumb))
    }

    func testAStickReportsItsOffsetAndItsLift() {
        XCTAssertEqual(stickMove(.left, CGVector(dx: 0.5, dy: -1)), .stick(.left, x: 0.5, y: -1))
        XCTAssertEqual(stickMove(.right, nil), .stickReleased(.right))
    }

    func testARailReportsHowFarDownAndItsLift() {
        XCTAssertEqual(railPull(.right, 0.25), .trigger(.right, railY: 0.25))
        XCTAssertEqual(railPull(.left, nil), .triggerReleased(.left))
    }

    func testTheDpadReportsItsOffsetAndItsLift() {
        XCTAssertEqual(dpadMove(CGVector(dx: 1, dy: 0)), .dpad(x: 1, y: 0))
        XCTAssertEqual(dpadMove(nil), .dpadReleased)
    }

    func testAFingerKeepsItsSlotAndLifts() {
        XCTAssertEqual(fingerMove(0, CGPoint(x: -1, y: 0.5)), .finger(.first, x: -1, y: 0.5))
        XCTAssertEqual(fingerMove(1, CGPoint(x: 0, y: 0)), .finger(.second, x: 0, y: 0))
        XCTAssertEqual(fingerMove(1, nil), .lifted(.second))
    }

    func testTheDpadLightsDiagonalsWhereTheReducerReadsThem() {
        XCTAssertEqual(Float(DishSize.dpadDiagonal), dpadDiagonalThreshold)
    }
}
