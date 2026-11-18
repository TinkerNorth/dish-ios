// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The play screens (C2, C3, C4) and the touchpad: the PC pill, the way
/// out, the gamepad's labels and touchpad for each emulated pad, and the
/// words and glyphs of the mouse and the touchpad.
final class PlayMappersTests: XCTestCase {

    private func cover(
        _ play: PlayFacts? = FactsFixture.play(),
        screen: PlayScreen = .gamepad,
        session: SessionFact? = nil,
        window: WindowFacts = WindowFixture.phoneOnItsSide
    ) -> PlayCoverState {
        playCoverState(facts: FactsFixture.shell(session: session, play: play), screen: screen, window: window)
    }

    // MARK: - The pill

    func testThePillNamesThePCAndItsLatencyInTheOnlineColour() {
        let pill = cover(session: FactsFixture.streaming()).pill
        XCTAssertEqual(
            pill,
            PlayPillState(pcName: "Living Room PC", detail: "4 ms", mark: .dot(DishTheme.success), detailColor: DishTheme.success)
        )
    }

    func testAPillWithNoLatencyYetSaysStreaming() {
        XCTAssertEqual(cover(session: FactsFixture.streaming(latencyMs: nil)).pill?.detail, "Streaming")
    }

    func testAPCThatStoppedAnsweringTurnsThePillToTheError() {
        let pill = cover(session: FactsFixture.stopped).pill
        XCTAssertEqual(pill?.detail, "Stopped responding")
        XCTAssertEqual(pill?.mark, .dot(DishTheme.error))
    }

    func testWithNoSessionThereIsNoPill() {
        XCTAssertNil(cover().pill)
    }

    /// The gamepad left alone counts down like the tabs do: the pill's detail
    /// takes the last seconds, and the latency comes back once a touch lands.
    func testThePillCountsDownToLowPower() {
        let counting = LowPowerFact(countdown: 5, due: false)
        XCTAssertEqual(playPill(FactsFixture.streaming(), lowPower: counting)?.detail, "Low power in 5 s")
        XCTAssertEqual(playPill(FactsFixture.streaming(), lowPower: .idle)?.detail, "4 ms")
        XCTAssertEqual(playPill(FactsFixture.stopped, lowPower: counting)?.detail, "Stopped responding", "nothing counts there")
    }

    /// A served slot bound to a PC with no session up reads lost, so the
    /// screen never goes quiet without a word.
    func testAServedSlotWhosePCIsDownReadsLost() {
        let lost = DestinationFact(id: "lr", name: "Living Room PC", health: .lost)
        let pill = cover(FactsFixture.play(destination: lost)).pill
        XCTAssertEqual(
            pill,
            PlayPillState(pcName: "Living Room PC", detail: "Connection lost", mark: .dot(DishTheme.error), detailColor: DishTheme.error)
        )
        XCTAssertEqual(
            cover(FactsFixture.play(destination: lost), session: FactsFixture.streaming()).pill?.detail,
            "4 ms",
            "the session's word first"
        )
    }

    /// A served slot whose PC is being reached for spins, and the session
    /// coming back at the person's asking spins the same way.
    func testAPCBeingReachedForSpinsOnThePill() {
        let reaching = DestinationFact(id: "lr", name: "Living Room PC", health: .connecting)
        XCTAssertEqual(
            cover(FactsFixture.play(destination: reaching)).pill,
            PlayPillState(pcName: "Living Room PC", detail: "Connecting…", mark: .busy, detailColor: DishTheme.muted)
        )
        XCTAssertEqual(cover(session: FactsFixture.reconnecting).pill?.mark, .busy)
        let failed = SessionFact(pcName: "Living Room PC", pads: 1, latencyMs: nil, phase: .failed(.dataPathBlocked))
        XCTAssertEqual(
            cover(session: failed).pill?.detail,
            "Connection lost",
            "the pill has no room for the reason; the accessory words it"
        )
        XCTAssertEqual(cover(session: failed).pill?.mark, .dot(DishTheme.error))
        let online = DestinationFact(id: "lr", name: "Living Room PC", health: .online)
        XCTAssertEqual(cover(FactsFixture.play(destination: online)).pill?.detail, "Online", "a PC up with no session word yet")
    }

    // MARK: - The way out, the glyphs and the touchpad

    func testTheWayOutIsABackButtonOnEveryScreen() {
        for screen in PlayScreen.allCases {
            XCTAssertEqual(cover(screen: screen).back, "Back", "\(screen)")
        }
    }

    func testTheMouseAndTheTouchpadWearTheirGlyphs() {
        XCTAssertEqual(cover(screen: .mouse).mouse.symbol, "computermouse")
        XCTAssertEqual(cover(screen: .touchpad).touchpad.symbol, "rectangle.and.hand.point.up.left")
        XCTAssertEqual(playScreenSymbol(.mouse), cover().mouse.symbol, "the row's Open mouse wears the same glyph")
        XCTAssertEqual(playScreenSymbol(.touchpad), cover().touchpad.symbol)
    }

    /// A DualShock 4, a DualSense and an Edge carry a touchpad, so their
    /// gamepad draws one; an Xbox pad and a Switch Pro have none.
    func testTheGamepadCarriesTheTouchpadOfThePadItEmulates() {
        XCTAssertTrue(cover(FactsFixture.play(emulateAs: .dualSense)).trackpad)
        XCTAssertTrue(cover(FactsFixture.play(emulateAs: .dualShock4)).trackpad)
        XCTAssertTrue(cover(FactsFixture.play(emulateAs: .dualSenseEdge)).trackpad)
        XCTAssertFalse(cover(FactsFixture.play(emulateAs: .xboxWireless)).trackpad)
        XCTAssertFalse(cover(FactsFixture.play(emulateAs: .switchPro)).trackpad)
        XCTAssertFalse(cover(nil).trackpad, "no play facts yet: the default Xbox pad")
    }

    /// L3 and R3 are sticks of their own beside each stick, seven tenths of
    /// it, as Android's are.
    func testTheClickSticksAreSevenTenthsOfTheSticks() {
        XCTAssertEqual(PadMetrics.compact.clickStick, 90)
        XCTAssertEqual(PadMetrics.compact.clickStickThumb, 42)
        XCTAssertEqual(PadMetrics.regular.clickStick, 140)
        XCTAssertEqual(PadMetrics.regular.clickStickThumb, 64)
        XCTAssertEqual(PadMetrics.compact.clickStick / PadMetrics.compact.stick, 0.7, accuracy: 0.01)
        XCTAssertEqual(PadMetrics.regular.clickStick / PadMetrics.regular.stick, 0.7, accuracy: 0.01)
    }

    func testTheTouchpadIsTwiceAsWideAsItIsHighAtEitherMeasure() {
        XCTAssertEqual(PadMetrics.compact.trackpad, CGSize(width: 200, height: 100))
        XCTAssertEqual(PadMetrics.regular.trackpad, CGSize(width: 300, height: 150))
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
            MouseCoverState(
                symbol: "computermouse",
                eyebrow: "Mouse",
                left: "Left",
                scroll: "Scroll",
                right: "Right",
                hint: "Drag to move the pointer"
            )
        )
    }

    func testTheTouchpadWordsItsClickZonesAndItsHint() {
        let touchpad = cover(screen: .touchpad).touchpad
        XCTAssertEqual(
            touchpad,
            TouchpadCoverState(
                symbol: "rectangle.and.hand.point.up.left",
                eyebrow: "Touchpad",
                click: "Click",
                hint: "Use one or two fingers"
            )
        )
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
            clickStick: DishSize.padClickStick,
            clickStickThumb: DishSize.padClickStickThumb,
            face: DishSize.padFace,
            dpadKey: DishSize.padDpadKey,
            rail: DishSize.padRail,
            trackpad: CGSize(width: DishSize.padTrackpadWidth, height: DishSize.padTrackpadHeight)
        )
        XCTAssertEqual(PadMetrics.compact, phone)
    }

    func testAnIPadOnItsSideGrowsTheSticksFacesRailsAndDpad() {
        XCTAssertEqual(cover(window: WindowFixture.iPadOnItsSide).pad, PadLayout(metrics: .regular, band: nil))
        let iPad = PadMetrics(
            stick: DishSize.padStickRegular,
            stickThumb: DishSize.padStickThumbRegular,
            clickStick: DishSize.padClickStickRegular,
            clickStickThumb: DishSize.padClickStickThumbRegular,
            face: DishSize.padFaceRegular,
            dpadKey: DishSize.padDpadKeyRegular,
            rail: DishSize.padRailRegular,
            trackpad: CGSize(width: DishSize.padTrackpadWidthRegular, height: DishSize.padTrackpadHeightRegular)
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

    /// One finger on L3 or R3 presses the button and tilts the stick, as a
    /// press on a real stick does both; its lift lets go of both.
    func testAClickStickPressesItsButtonAsItTilts() {
        XCTAssertEqual(clickStickEvents(.left, CGVector(dx: 0.5, dy: -1)), [.press(.leftThumb), .stick(.left, x: 0.5, y: -1)])
        XCTAssertEqual(clickStickEvents(.right, CGVector(dx: 0, dy: 0)), [.press(.rightThumb), .stick(.right, x: 0, y: 0)])
        XCTAssertEqual(clickStickEvents(.left, nil), [.stickReleased(.left), .release(.leftThumb)])
        XCTAssertEqual(clickStickEvents(.right, nil), [.stickReleased(.right), .release(.rightThumb)])
        XCTAssertEqual(thumbButton(.left), .leftThumb)
        XCTAssertEqual(thumbButton(.right), .rightThumb)
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
