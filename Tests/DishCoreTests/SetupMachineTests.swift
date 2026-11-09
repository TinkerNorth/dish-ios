// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// The phone's setup walk as data: Welcome, Input · 1 of 3, the Destination
/// step (the Local Network primer while iOS has not been asked, else Pick
/// your PC), Review and bind · 3 of 3. Skip ends it from anywhere, Back walks
/// one step, and nothing is sent until Bind.
final class SetupMachineTests: XCTestCase {

    private let dualSense = InputKind.detectedPad(id: "pad-1", family: .dualSense)
    private let den = DestinationPick.satellite(id: "den")

    private func reduce(
        _ state: SetupState,
        _ event: SetupEvent,
        localNetwork: LocalNetworkStatus = .unknown
    ) -> (state: SetupState, effects: [SetupEffect]) {
        reduceSetup(state, event, localNetwork: localNetwork)
    }

    private func run(_ state: SetupState, _ events: [SetupEvent], localNetwork: LocalNetworkStatus = .unknown) -> SetupState {
        events.reduce(state) { reduceSetup($0, $1, localNetwork: localNetwork).state }
    }

    private var onWelcome: SetupState {
        SetupState(start: .welcome)
    }

    private var onInput: SetupState {
        run(onWelcome, [.next])
    }

    private var onInputFromAddController: SetupState {
        SetupState(start: .input)
    }

    private var onPrimer: SetupState {
        run(onInput, [.pickInput(dualSense)])
    }

    private var onPickPC: SetupState {
        run(onInput, [.pickInput(dualSense)], localNetwork: .allowed)
    }

    private var onReview: SetupState {
        run(onPickPC, [.pickDestination(den)], localNetwork: .allowed)
    }

    private var everyStep: [SetupState] {
        [onWelcome, onInput, onPrimer, onPickPC, onReview]
    }

    // MARK: - Opening

    func testAFirstRunOpensOnTheWelcomeWithNothingAnswered() {
        let state = onWelcome
        XCTAssertEqual(state.step, .welcome)
        XCTAssertEqual(state.start, .welcome)
        XCTAssertEqual(state.draft, SetupDraft())
    }

    func testAddingAControllerOpensOnInput() {
        let state = onInputFromAddController
        XCTAssertEqual(state.step, .input)
        XCTAssertEqual(state.start, .input)
    }

    func testBeginningStartsAFreshWalkFromAnyStepAndDropsTheAnswers() {
        for state in everyStep {
            let welcome = reduce(state, .begin(at: .welcome))
            XCTAssertEqual(welcome.state, SetupState(start: .welcome))
            XCTAssertEqual(welcome.effects, [])
            let input = reduce(state, .begin(at: .input))
            XCTAssertEqual(input.state, SetupState(start: .input))
            XCTAssertEqual(input.effects, [])
        }
    }

    // MARK: - Welcome

    func testContinueOnTheWelcomeMovesToInputQuietly() {
        let step = reduce(onWelcome, .next)
        XCTAssertEqual(step.state.step, .input)
        XCTAssertEqual(step.effects, [])
    }

    // MARK: - Skip

    func testSkipEndsTheWalkFromEveryStepAndLeavesTheStateAlone() {
        for state in everyStep + [onInputFromAddController] {
            let step = reduce(state, .skip)
            XCTAssertEqual(step.state, state, "on \(state.step)")
            XCTAssertEqual(step.effects, [.ended(.skipped)], "on \(state.step)")
        }
    }

    // MARK: - Back

    func testThereIsNoBackFromTheWelcome() {
        let step = reduce(onWelcome, .back)
        XCTAssertEqual(step.state, onWelcome)
        XCTAssertEqual(step.effects, [])
    }

    func testBackFromInputReturnsToTheWelcomeItCameFrom() {
        let step = reduce(onInput, .back)
        XCTAssertEqual(step.state.step, .welcome)
        XCTAssertEqual(step.effects, [])
    }

    func testThereIsNoBackFromInputWhenTheWalkOpenedThere() {
        let step = reduce(onInputFromAddController, .back)
        XCTAssertEqual(step.state, onInputFromAddController)
        XCTAssertEqual(step.effects, [])
    }

    func testBackFromThePrimerReturnsToInputAndKeepsThePick() {
        let step = reduce(onPrimer, .back)
        XCTAssertEqual(step.state.step, .input)
        XCTAssertEqual(step.state.draft.input, dualSense)
        XCTAssertEqual(step.effects, [])
    }

    func testBackFromPickYourPCReturnsToInput() {
        let step = reduce(onPickPC, .back, localNetwork: .allowed)
        XCTAssertEqual(step.state.step, .input)
        XCTAssertEqual(step.effects, [])
    }

    func testBackFromReviewReturnsToPickYourPCOnceTheLocalNetworkIsAnswered() {
        XCTAssertEqual(reduce(onReview, .back, localNetwork: .allowed).state.step, .pickPC)
        XCTAssertEqual(reduce(onReview, .back, localNetwork: .denied).state.step, .pickPC)
        XCTAssertEqual(reduce(onReview, .back, localNetwork: .allowed).effects, [])
    }

    func testBackFromReviewReturnsToThePrimerWhileTheLocalNetworkIsUnasked() {
        let byAddress = run(onPrimer, [.pickDestination(.byAddress)])
        let step = reduce(byAddress, .back)
        XCTAssertEqual(step.state.step, .localNetworkPrimer)
        XCTAssertEqual(step.effects, [])
    }

    // MARK: - Input

    func testPickingAnInputWhileTheLocalNetworkIsUnaskedOpensThePrimer() {
        let step = reduce(onInput, .pickInput(.wired))
        XCTAssertEqual(step.state.step, .localNetworkPrimer)
        XCTAssertEqual(step.state.draft.input, .wired)
        XCTAssertEqual(step.effects, [], "the question waits for the primer's Continue")
    }

    func testPickingAnInputOnceTheLocalNetworkIsAllowedOpensPickYourPCAndScans() {
        let step = reduce(onInput, .pickInput(.bluetooth), localNetwork: .allowed)
        XCTAssertEqual(step.state.step, .pickPC)
        XCTAssertEqual(step.state.draft.input, .bluetooth)
        XCTAssertEqual(step.effects, [.scan])
    }

    func testPickingAnInputOnceTheLocalNetworkIsDeniedOpensPickYourPCWithoutAScan() {
        let step = reduce(onInput, .pickInput(.onScreen), localNetwork: .denied)
        XCTAssertEqual(step.state.step, .pickPC)
        XCTAssertEqual(step.effects, [], "nothing can be heard; Pick your PC says why")
    }

    func testContinueOnInputWaitsForAPick() {
        let step = reduce(onInput, .next)
        XCTAssertEqual(step.state, onInput)
        XCTAssertEqual(step.effects, [])
    }

    func testAnInputPickedAwayFromInputIsIgnored() {
        for state in [onWelcome, onPrimer, onPickPC, onReview] {
            let step = reduce(state, .pickInput(.wired), localNetwork: .allowed)
            XCTAssertEqual(step.state, state, "on \(state.step)")
            XCTAssertEqual(step.effects, [], "on \(state.step)")
        }
    }

    // MARK: - Emulate as follows the pad

    func testASeenPadEmulatesItsOwnFamily() {
        for family in EmulatedPad.allCases {
            let pad = InputKind.detectedPad(id: "pad", family: family)
            let state = run(onInput, [.pickInput(pad)])
            XCTAssertEqual(state.draft.emulateAs, family)
            XCTAssertEqual(state.draft.motion, family.hasMotion, "motion is on where the pad has it")
        }
    }

    func testAnUnseenPadOrTheScreenEmulatesAnXboxWirelessWithoutMotion() {
        for kind in [InputKind.wired, .bluetooth, .onScreen] {
            let state = run(onInput, [.pickInput(kind)])
            XCTAssertEqual(state.draft.emulateAs, .xboxWireless)
            XCTAssertFalse(state.draft.motion)
        }
    }

    func testPickingAgainAfterGoingBackReplacesTheEmulation() {
        let state = run(onInput, [.pickInput(dualSense), .back, .pickInput(.wired)])
        XCTAssertEqual(state.draft.input, .wired)
        XCTAssertEqual(state.draft.emulateAs, .xboxWireless)
    }

    // MARK: - The Local Network primer

    func testContinueOnThePrimerAsksIOSAndWaitsForTheAnswer() {
        let step = reduce(onPrimer, .next)
        XCTAssertEqual(step.state, onPrimer)
        XCTAssertEqual(step.effects, [.askLocalNetwork])
    }

    func testContinueOnThePrimerOnceAllowedMovesOnAndScans() {
        let step = reduce(onPrimer, .next, localNetwork: .allowed)
        XCTAssertEqual(step.state.step, .pickPC)
        XCTAssertEqual(step.effects, [.scan], "iOS asks once; an earlier answer is the answer")
    }

    func testContinueOnThePrimerOnceDeniedMovesOnWithoutAScan() {
        let step = reduce(onPrimer, .next, localNetwork: .denied)
        XCTAssertEqual(step.state.step, .pickPC)
        XCTAssertEqual(step.effects, [])
    }

    func testAllowingMovesToPickYourPCAndScans() {
        let step = reduce(onPrimer, .localNetworkAnswered(allowed: true), localNetwork: .allowed)
        XCTAssertEqual(step.state.step, .pickPC)
        XCTAssertEqual(step.effects, [.scan])
    }

    func testDenyingMovesToPickYourPCWithoutAScan() {
        let step = reduce(onPrimer, .localNetworkAnswered(allowed: false), localNetwork: .denied)
        XCTAssertEqual(step.state.step, .pickPC, "Pick your PC shows the refusal")
        XCTAssertEqual(step.effects, [])
    }

    func testAnAllowWhileOnPickYourPCScansAgain() {
        let refused = run(onPrimer, [.localNetworkAnswered(allowed: false)], localNetwork: .denied)
        let step = reduce(refused, .localNetworkAnswered(allowed: true), localNetwork: .allowed)
        XCTAssertEqual(step.state, refused)
        XCTAssertEqual(step.effects, [.scan], "turned on in Settings: look now")
        XCTAssertEqual(reduce(refused, .localNetworkAnswered(allowed: false), localNetwork: .denied).effects, [])
    }

    func testAnAnswerAnywhereElseChangesNothing() {
        for state in [onWelcome, onInput, onReview] {
            for allowed in [true, false] {
                let step = reduce(state, .localNetworkAnswered(allowed: allowed), localNetwork: .allowed)
                XCTAssertEqual(step.state, state, "on \(state.step)")
                XCTAssertEqual(step.effects, [], "on \(state.step)")
            }
        }
    }

    // MARK: - Pick your PC

    func testPickingAPCMovesToReview() {
        let step = reduce(onPickPC, .pickDestination(den), localNetwork: .allowed)
        XCTAssertEqual(step.state.step, .review)
        XCTAssertEqual(step.state.draft.destination, den)
        XCTAssertEqual(step.effects, [])
    }

    func testPickingAMoonlightHostMovesToReview() {
        let host = DestinationPick.moonlightHost(id: "office")
        let state = run(onPickPC, [.pickDestination(host)], localNetwork: .allowed)
        XCTAssertEqual(state.step, .review)
        XCTAssertEqual(state.draft.destination, host)
    }

    func testAddingByAddressFromThePrimerSkipsTheQuestionAndMovesToReview() {
        let step = reduce(onPrimer, .pickDestination(.byAddress))
        XCTAssertEqual(step.state.step, .review)
        XCTAssertEqual(step.state.draft.destination, .byAddress)
        XCTAssertEqual(step.effects, [])
    }

    func testContinueOnPickYourPCWaitsForAPick() {
        let step = reduce(onPickPC, .next, localNetwork: .allowed)
        XCTAssertEqual(step.state, onPickPC)
        XCTAssertEqual(step.effects, [])
    }

    func testADestinationPickedOnWelcomeInputOrReviewIsIgnored() {
        for state in [onWelcome, onInput, onReview] {
            let step = reduce(state, .pickDestination(.byAddress), localNetwork: .allowed)
            XCTAssertEqual(step.state, state, "on \(state.step)")
            XCTAssertEqual(step.effects, [])
        }
    }

    // MARK: - Review and bind

    func testChangingTheEmulatedPadResetsMotionToWhatThePadCarries() {
        let xbox = run(onReview, [.setEmulateAs(.xboxWireless)])
        XCTAssertEqual(xbox.draft.emulateAs, .xboxWireless)
        XCTAssertFalse(xbox.draft.motion)
        let switchPro = run(xbox, [.setEmulateAs(.switchPro)])
        XCTAssertEqual(switchPro.draft.emulateAs, .switchPro)
        XCTAssertTrue(switchPro.draft.motion)
    }

    func testMotionTurnsOffAndOnForAPadThatHasIt() {
        let off = reduce(onReview, .setMotion(false))
        XCTAssertFalse(off.state.draft.motion)
        XCTAssertEqual(off.effects, [])
        XCTAssertTrue(run(off.state, [.setMotion(true)]).draft.motion)
    }

    func testMotionStaysOffForAPadWithoutIt() {
        let xbox = run(onReview, [.setEmulateAs(.xboxWireless), .setMotion(true)])
        XCTAssertFalse(xbox.draft.motion)
    }

    func testEditsAwayFromReviewAreIgnored() {
        for state in [onWelcome, onInput, onPrimer, onPickPC] {
            let edited = run(state, [.setEmulateAs(.switchPro), .setMotion(true)])
            XCTAssertEqual(edited, state, "on \(state.step)")
        }
    }

    func testBindAsksForTheDraftThenEndsTheWalk() {
        let edited = run(onReview, [.setEmulateAs(.dualShock4), .setMotion(false)])
        let step = reduce(edited, .bind, localNetwork: .allowed)
        let expected = SetupDraft(input: dualSense, destination: den, emulateAs: .dualShock4, motion: false)
        XCTAssertEqual(step.effects, [.bind(expected), .ended(.bound)])
        XCTAssertEqual(step.state, edited)
    }

    func testContinueOnReviewIsNotBind() {
        let step = reduce(onReview, .next, localNetwork: .allowed)
        XCTAssertEqual(step.state, onReview)
        XCTAssertEqual(step.effects, [])
    }

    func testBindAwayFromReviewIsIgnored() {
        for state in [onWelcome, onInput, onPrimer, onPickPC] {
            let step = reduce(state, .bind, localNetwork: .allowed)
            XCTAssertEqual(step.state, state, "on \(state.step)")
            XCTAssertEqual(step.effects, [], "on \(state.step)")
        }
    }

    // MARK: - Step number and Back per step

    func testTheStepNumberCountsInputDestinationAndBinding() {
        XCTAssertNil(onWelcome.stepNumber)
        XCTAssertEqual(onInput.stepNumber, 1)
        XCTAssertEqual(onInputFromAddController.stepNumber, 1)
        XCTAssertEqual(onPrimer.stepNumber, 2)
        XCTAssertEqual(onPickPC.stepNumber, 2)
        XCTAssertEqual(onReview.stepNumber, 3)
    }

    func testEveryStepButTheFirstHasAWayBack() {
        XCTAssertFalse(onWelcome.canGoBack)
        XCTAssertTrue(onInput.canGoBack)
        XCTAssertFalse(onInputFromAddController.canGoBack)
        XCTAssertTrue(onPrimer.canGoBack)
        XCTAssertTrue(onPickPC.canGoBack)
        XCTAssertTrue(onReview.canGoBack)
    }

    // MARK: - A whole walk

    func testAFirstRunWalksWelcomeToBindAskingOnceAndScanningOnce() {
        let opened = SetupState(start: .welcome)
        let input = reduce(opened, .next)
        let primer = reduce(input.state, .pickInput(.wired))
        let asked = reduce(primer.state, .next)
        let answered = reduce(asked.state, .localNetworkAnswered(allowed: true), localNetwork: .allowed)
        let picked = reduce(answered.state, .pickDestination(den), localNetwork: .allowed)
        let bound = reduce(picked.state, .bind, localNetwork: .allowed)
        let effects = [input, primer, asked, answered, picked, bound].flatMap(\.effects)
        let draft = SetupDraft(input: .wired, destination: den, emulateAs: .xboxWireless, motion: false)
        XCTAssertEqual(effects, [.askLocalNetwork, .scan, .bind(draft), .ended(.bound)])
    }
}
