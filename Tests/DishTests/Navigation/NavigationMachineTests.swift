// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import XCTest
@testable import Dish

/// Every event against every state the machine can be in
/// (docs/UI_CONTRACT.md, "The shell").
final class NavigationMachineTests: XCTestCase {

    private func after(_ events: NavigationEvent..., from start: NavigationState = NavigationState()) -> NavigationStep {
        events.reduce(NavigationStep(state: start, effects: [])) { step, event in
            let next = reduceNavigation(step.state, event)
            return NavigationStep(state: next.state, effects: step.effects + next.effects)
        }
    }

    func testTheAppOpensOnControllersWithEmptyStacksAndNoCover() {
        let state = NavigationState()
        XCTAssertEqual(state.tab, .controllers)
        XCTAssertEqual(Tab.allCases.map(state.path(of:)), [[], [], []])
        XCTAssertNil(state.cover)
    }

    func testSelectingATabSwitchesAndKeepsEveryTabsStack() {
        let step = after(.select(.settings), .push(.deviceName), .select(.connections))
        XCTAssertEqual(step.state.tab, .connections)
        XCTAssertEqual(step.state.path(of: .settings), [.deviceName], "the stack waits for the tab to come back")
        XCTAssertEqual(step.state.path(of: .connections), [])
        XCTAssertEqual(step.effects, [])
    }

    func testSelectingTheTabOnScreenPopsItToItsRoot() {
        let step = after(.select(.settings), .push(.deviceName), .select(.settings))
        XCTAssertEqual(step.state.tab, .settings)
        XCTAssertEqual(step.state.path(of: .settings), [])
    }

    func testSupportDishOpensFromTheControllersHeartAndFromSettings() {
        let fromHeart = after(.push(.support))
        XCTAssertEqual(fromHeart.state.path(of: .controllers), [.support])
        let fromSettings = after(.select(.settings), .push(.support))
        XCTAssertEqual(fromSettings.state.path(of: .settings), [.support])
        XCTAssertEqual(fromSettings.state.path(of: .controllers), [])
    }

    func testHelpAndTheLicensesPushOntoSettings() {
        let step = after(.select(.settings), .push(.help), .select(.settings), .push(.licenses))
        XCTAssertEqual(step.state.path(of: .settings), [.licenses], "a tap on Settings unwinds Help first")
    }

    func testDiagnosticsPushesOntoSettings() {
        let step = after(.select(.settings), .push(.diagnostics))
        XCTAssertEqual(step.state.path(of: .settings), [.diagnostics])
        XCTAssertEqual(step.effects, [], "a page starts nothing in the model; its appearance does")
    }

    func testAPushLandsOnTheTabOnScreen() {
        let step = after(.select(.settings), .push(.deviceName))
        XCTAssertEqual(step.state.path(of: .settings), [.deviceName])
        XCTAssertEqual(step.state.path(of: .controllers), [])
    }

    func testTheStacksOwnMoveIsRecorded() {
        let step = after(.select(.settings), .push(.deviceName), .pathChanged(.settings, []))
        XCTAssertEqual(step.state.path(of: .settings), [])
        XCTAssertEqual(step.state.tab, .settings)
    }

    func testOpeningSetupRaisesTheCoverAtItsEntryAndStartsTheWalk() {
        for entry in [SetupEntry.firstRun, .addController, .guide] {
            let step = after(.openSetup(entry))
            XCTAssertEqual(step.state.cover, .setup(entry))
            XCTAssertEqual(step.effects, [.startSetup(entry)])
        }
        XCTAssertEqual(after(.dim, .openSetup(.guide)).state.cover, .setup(.guide), "setup takes the dim's place")
    }

    func testSkippingSetupLandsOnControllersAndCompletesTheWelcome() {
        let step = after(.select(.settings), .openSetup(.guide), .setupEnded(.skipped))
        XCTAssertNil(step.state.cover)
        XCTAssertEqual(step.state.tab, .controllers)
        XCTAssertEqual(step.effects, [.startSetup(.guide), .endSetup, .markWelcomeComplete])
    }

    func testBindingLandsOnControllersAndCompletesTheWelcome() {
        let step = after(.openSetup(.firstRun), .setupEnded(.bound))
        XCTAssertNil(step.state.cover)
        XCTAssertEqual(step.state.tab, .controllers)
        XCTAssertEqual(step.effects, [.startSetup(.firstRun), .endSetup, .markWelcomeComplete])
    }

    func testASetupEndingWithNoSetupUpChangesNothing() {
        let before = after(.select(.connections)).state
        let step = reduceNavigation(before, .setupEnded(.skipped))
        XCTAssertEqual(step.state, before)
        XCTAssertEqual(step.effects, [])
        let dimmed = after(.dim).state
        XCTAssertEqual(reduceNavigation(dimmed, .setupEnded(.bound)).state, dimmed, "the dim is not setup")
    }

    func testTheDimRisesOnlyOverTheTabs() {
        XCTAssertEqual(after(.dim).state.cover, .dim)
        XCTAssertEqual(after(.openSetup(.firstRun), .dim).state.cover, .setup(.firstRun), "setup stays")
        XCTAssertEqual(after(.dim).effects, [])
    }

    func testWakingLowersTheDimAndNothingElse() {
        let woken = after(.dim, .wake)
        XCTAssertNil(woken.state.cover)
        XCTAssertEqual(woken.effects, [])
        XCTAssertEqual(after(.openSetup(.guide), .wake).state.cover, .setup(.guide))
        XCTAssertEqual(after(.wake).state, NavigationState())
    }

    func testADismissedCoverEndsWhatItShowed() {
        let skipped = after(.openSetup(.firstRun), .coverDismissed)
        XCTAssertNil(skipped.state.cover)
        XCTAssertEqual(skipped.state.tab, .controllers)
        XCTAssertEqual(skipped.effects, [.startSetup(.firstRun), .endSetup, .markWelcomeComplete])
        let woken = after(.dim, .coverDismissed)
        XCTAssertNil(woken.state.cover)
        XCTAssertEqual(woken.effects, [])
        XCTAssertEqual(after(.coverDismissed).state, NavigationState(), "nothing to lower")
    }

    func testOpeningAPlayScreenRaisesItsCoverAndStartsIt() {
        for screen in PlayScreen.allCases {
            let step = after(.select(.settings), .openPlay(screen))
            XCTAssertEqual(step.state.cover, .play(screen))
            XCTAssertEqual(step.state.tab, .settings, "the tabs wait under the cover")
            XCTAssertEqual(step.effects, [.startPlay(screen)])
        }
    }

    func testClosingPlayLowersItsCoverAndEndsIt() {
        let step = after(.openPlay(.gamepad), .closePlay)
        XCTAssertNil(step.state.cover)
        XCTAssertEqual(step.effects, [.startPlay(.gamepad), .endPlay])
    }

    func testClosingPlayWithNoPlayUpChangesNothing() {
        XCTAssertEqual(after(.closePlay).state, NavigationState())
        XCTAssertEqual(after(.closePlay).effects, [])
        let step = after(.openSetup(.guide), .closePlay)
        XCTAssertEqual(step.state.cover, .setup(.guide), "setup is not play")
        XCTAssertEqual(step.effects, [.startSetup(.guide)])
    }

    func testThePauseMenuMovesFromOneScreenToAnotherUnderOneCover() {
        let step = after(.openPlay(.gamepad), .openPlay(.mouse))
        XCTAssertEqual(step.state.cover, .play(.mouse))
        XCTAssertEqual(step.effects, [.startPlay(.gamepad), .startPlay(.mouse)], "a screen replacing a screen ends nothing")
        XCTAssertEqual(Cover.play(.gamepad).id, Cover.play(.mouse).id, "the same presentation stays up")
    }

    func testACoverReplacingAnotherEndsWhatItReplaced() {
        let setupOverPlay = after(.openPlay(.gamepad), .openSetup(.addController))
        XCTAssertEqual(setupOverPlay.state.cover, .setup(.addController))
        XCTAssertEqual(setupOverPlay.effects, [.startPlay(.gamepad), .endPlay, .startSetup(.addController)])
        let playOverSetup = after(.openSetup(.firstRun), .openPlay(.touchpad))
        XCTAssertEqual(playOverSetup.state.cover, .play(.touchpad))
        XCTAssertEqual(playOverSetup.effects, [.startSetup(.firstRun), .endSetup, .startPlay(.touchpad)])
        let playOverDim = after(.dim, .openPlay(.gamepad))
        XCTAssertEqual(playOverDim.state.cover, .play(.gamepad))
        XCTAssertEqual(playOverDim.effects, [.startPlay(.gamepad)], "the dim ends with nothing to end")
    }

    /// The design puts Dim on the accessory, which no play screen shows.
    func testTheDimIsRefusedOverPlay() {
        let step = after(.openPlay(.gamepad), .dim)
        XCTAssertEqual(step.state.cover, .play(.gamepad))
        XCTAssertEqual(step.effects, [.startPlay(.gamepad)])
    }

    func testADismissedPlayCoverClosesPlay() {
        let step = after(.openPlay(.mouse), .coverDismissed)
        XCTAssertNil(step.state.cover)
        XCTAssertEqual(step.effects, [.startPlay(.mouse), .endPlay])
    }

    func testPlayIsLandscapeAndEveryOtherScreenPortrait() {
        for screen in PlayScreen.allCases {
            XCTAssertEqual(screenOrientation(for: .play(screen)), .landscape)
        }
        for cover in [Cover.setup(.firstRun), .dim, nil] {
            XCTAssertEqual(screenOrientation(for: cover), .portrait)
        }
    }

    func testAControllerRowPushesItsPageOntoControllers() {
        let step = after(.select(.controllers), .push(.controller(id: "pad")))
        XCTAssertEqual(step.state.path(of: .controllers), [.controller(id: "pad")])
    }
}
