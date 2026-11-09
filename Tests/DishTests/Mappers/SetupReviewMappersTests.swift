// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import Dish

final class SetupReviewMappersTests: XCTestCase {

    private let seenDualSense = InputKind.detectedPad(id: "pad-1", family: .dualSense)

    private func review(
        _ input: InputKind,
        _ destination: DestinationPick,
        edits: [SetupEvent] = [],
        inputs: SetupInputs = SetupFixture.inputs()
    ) -> ReviewStepState {
        let walk = SetupFixture.walk(.input, [.pickInput(input), .pickDestination(destination)] + edits)
        return reviewStepState(walk.draft, inputs)
    }

    private func carried(_ column: CarryColumn) -> [String] {
        column.rows.filter(\.carried).map(\.title)
    }

    // MARK: - The words

    func testReviewAsksToCheckTheLinkThenBind() {
        let state = review(.wired, .byAddress)
        XCTAssertEqual(state.title, "Review and bind")
        XCTAssertEqual(state.body, "Check the link, then bind it. Nothing changes on your PC until you do.")
        XCTAssertEqual(state.emulateTitle, "Emulate as")
        XCTAssertEqual(state.motionTitle, "Motion")
        XCTAssertEqual(state.carriesTitle, "What carries")
        XCTAssertEqual(state.sends.title, "Sends to PC")
        XCTAssertEqual(state.getsBack.title, "Gets back")
        XCTAssertEqual(state.primary, "Bind")
        XCTAssertEqual(state.emulateOptions.map(\.name), ["DualSense", "DualShock 4", "Xbox Wireless", "Switch Pro"])
    }

    // MARK: - The pad's end

    func testASeenPadShowsItsNameLinkAndBattery() {
        let state = review(seenDualSense, .byAddress, inputs: SetupFixture.inputs(pads: [SetupFixture.dualSense]))
        XCTAssertEqual(state.pad, ReviewEndState(symbol: "gamecontroller", name: "DualSense", detail: "USB-C · 84%", dot: nil))
    }

    func testAPadThatLeftShowsItsFamilyAlone() {
        let state = review(.detectedPad(id: "gone", family: .switchPro), .byAddress)
        XCTAssertEqual(state.pad, ReviewEndState(symbol: "gamecontroller", name: "Switch Pro", detail: nil, dot: nil))
    }

    func testTheThreeWaysInShowTheirOwnNames() {
        XCTAssertEqual(review(.wired, .byAddress).pad?.name, "Wired controller")
        XCTAssertEqual(review(.wired, .byAddress).pad?.detail, "USB-C")
        XCTAssertEqual(review(.bluetooth, .byAddress).pad?.detail, "Bluetooth")
        XCTAssertEqual(review(.onScreen, .byAddress).pad, ReviewEndState(
            symbol: "iphone",
            name: "On-screen gamepad",
            detail: "This iPhone",
            dot: nil
        ))
    }

    func testADraftWithoutAnswersShowsNeitherEnd() {
        let state = reviewStepState(SetupDraft(), SetupFixture.inputs())
        XCTAssertNil(state.pad)
        XCTAssertNil(state.pc)
    }

    // MARK: - The PC's end

    func testAPairedPCSaysPairedInGreen() {
        let inputs = SetupFixture.inputs(found: [SetupFixture.office])
        let state = review(.wired, .satellite(id: "office"), inputs: inputs)
        XCTAssertEqual(state.pc, ReviewEndState(symbol: "desktopcomputer", name: "Office PC", detail: "Paired", dot: DishTheme.success))
    }

    func testAnUnpairedMoonlightHostNeedsPairing() {
        let inputs = SetupFixture.inputs(found: [SetupFixture.den])
        let state = review(.wired, .moonlightHost(id: "den"), inputs: inputs)
        XCTAssertEqual(state.pc, ReviewEndState(symbol: "display", name: "Den PC", detail: "Needs pairing", dot: DishTheme.warning))
    }

    func testAPCThatWentQuietIsYourPCStillToPair() {
        let state = review(.wired, .satellite(id: "gone"))
        XCTAssertEqual(
            state.pc,
            ReviewEndState(symbol: "desktopcomputer", name: "Your PC", detail: "Needs pairing", dot: DishTheme.warning)
        )
    }

    func testAPCByAddressIsStillToPair() {
        XCTAssertEqual(review(.wired, .byAddress).pc, ReviewEndState(
            symbol: "network",
            name: "A PC by address",
            detail: "Needs pairing",
            dot: DishTheme.warning
        ))
    }

    // MARK: - What carries, per emulated pad

    func testADualSenseCarriesMotionTouchpadTriggersAndTheLightBar() {
        let state = review(seenDualSense, .byAddress)
        XCTAssertEqual(state.emulateAs, .dualSense)
        XCTAssertTrue(state.motion)
        XCTAssertTrue(state.motionEnabled)
        XCTAssertEqual(carried(state.sends), ["Buttons, sticks", "Motion", "Touchpad", "Battery"])
        XCTAssertEqual(carried(state.getsBack), ["Rumble", "Trigger effects", "Light bar"])
        XCTAssertEqual(
            state.footnote,
            "DualSense carries motion, touchpad and adaptive triggers. The other pads are in the menu."
        )
    }

    func testADualShock4CarriesMotionTouchpadAndTheLightBar() {
        let state = review(.wired, .byAddress, edits: [.setEmulateAs(.dualShock4)])
        XCTAssertEqual(carried(state.sends), ["Buttons, sticks", "Motion", "Touchpad", "Battery"])
        XCTAssertEqual(carried(state.getsBack), ["Rumble", "Light bar"])
        XCTAssertEqual(state.footnote, "DualShock 4 carries motion, touchpad and the light bar. The other pads are in the menu.")
    }

    func testAnXboxWirelessCarriesRumbleAndNoMotion() {
        let state = review(.wired, .byAddress)
        XCTAssertEqual(state.emulateAs, .xboxWireless)
        XCTAssertFalse(state.motion)
        XCTAssertFalse(state.motionEnabled, "nothing to switch")
        XCTAssertEqual(carried(state.sends), ["Buttons, sticks", "Battery"])
        XCTAssertEqual(carried(state.getsBack), ["Rumble"])
        XCTAssertEqual(state.footnote, "Xbox Wireless carries rumble, without motion or a touchpad. The other pads are in the menu.")
    }

    func testASwitchProCarriesMotionAndRumble() {
        let state = review(.wired, .byAddress, edits: [.setEmulateAs(.switchPro)])
        XCTAssertEqual(carried(state.sends), ["Buttons, sticks", "Motion", "Battery"])
        XCTAssertEqual(carried(state.getsBack), ["Rumble"])
        XCTAssertEqual(state.footnote, "Switch Pro carries motion and rumble. The other pads are in the menu.")
    }

    func testMotionSwitchedOffIsNotSent() {
        let state = review(seenDualSense, .byAddress, edits: [.setMotion(false)])
        XCTAssertFalse(state.motion)
        XCTAssertTrue(state.motionEnabled)
        XCTAssertEqual(carried(state.sends), ["Buttons, sticks", "Touchpad", "Battery"])
    }

    func testTheSpeakerNeverComesBack() {
        for pad in EmulatedPad.allCases {
            let state = review(.wired, .byAddress, edits: [.setEmulateAs(pad)])
            let speaker = state.getsBack.rows.last
            XCTAssertEqual(
                speaker,
                CarryRow(title: "Speaker", carried: false, symbol: "minus", tint: DishTheme.muted, label: DishTheme.muted)
            )
        }
    }

    func testACarriedRowIsAGreenCheck() {
        let first = review(.wired, .byAddress).sends.rows.first
        XCTAssertEqual(
            first,
            CarryRow(title: "Buttons, sticks", carried: true, symbol: "checkmark", tint: DishTheme.success, label: DishTheme.onSurface)
        )
    }

    func testTheCarriesTable() {
        XCTAssertEqual(padCarries(.dualSense), PadCarries(touchpad: true, triggerEffects: true, lightBar: true))
        XCTAssertEqual(padCarries(.dualShock4), PadCarries(touchpad: true, triggerEffects: false, lightBar: true))
        XCTAssertEqual(padCarries(.xboxWireless), PadCarries(touchpad: false, triggerEffects: false, lightBar: false))
        XCTAssertEqual(padCarries(.switchPro), PadCarries(touchpad: false, triggerEffects: false, lightBar: false))
    }
}
