// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import XCTest
@testable import Dish

/// The hints TipKit shows (the heart, Add a controller, the pause menu's
/// way out and the dim): their words, and what puts each to rest.
final class HintMappersTests: XCTestCase {

    /// The hint `event` puts to rest when it reaches `state`.
    private func learned(_ event: NavigationEvent, from state: NavigationState = NavigationState()) -> Hint? {
        learnedHint(event, from: state, to: reduceNavigation(state, event).state)
    }

    // MARK: - Words

    func testTheHeartsHintSaysWhatSupportDishIs() {
        XCTAssertEqual(hintState(.supportDish), HintState(
            id: "dish.hint.support-dish",
            title: "Support Dish",
            message: "Dish is free and open source. Every feature stays free, tip or not.",
            symbol: "heart.fill",
            urgent: false
        ))
    }

    /// Dish cannot pair a Bluetooth pad, so the hint points at Settings.
    func testAddAControllersHintPointsAtSettingsBluetooth() {
        XCTAssertEqual(hintState(.addController), HintState(
            id: "dish.hint.add-a-controller",
            title: "Bring the controller you own",
            message: "Apps can’t pair Bluetooth devices, so Dish leaves that to iOS. Pair it in Settings › Bluetooth first, or plug it in.",
            symbol: "gamecontroller",
            urgent: false
        ))
    }

    /// Play hides every way out but the pause menu, so its hint shows even
    /// on a day another hint has.
    func testThePauseButtonsHintIsTheWayOutAndShowsOnABusyDay() {
        XCTAssertEqual(hintState(.stopGamepad), HintState(
            id: "dish.hint.stop-gamepad",
            title: "Leave through the pause menu",
            message: "Stop gamepad in this menu takes you back to Dish.",
            symbol: "stop.fill",
            urgent: true
        ))
    }

    func testTheDimsHintSaysStreamingGoesOn() {
        XCTAssertEqual(hintState(.dim), HintState(
            id: "dish.hint.dim",
            title: "Dim the screen while you play",
            message: "Streaming continues while dimmed. "
                + "Tap the dimmed screen to wake it, and set the delay in Settings › Dim screen after.",
            symbol: "moon.fill",
            urgent: false
        ))
    }

    func testEveryHintHasANameOfItsOwn() {
        let names = Set(Hint.allCases.map { hintState($0).id })
        XCTAssertEqual(names.count, Hint.allCases.count)
    }

    func testThePauseMenuCarriesTheWayOutsHint() {
        XCTAssertEqual(pauseMenuState(play: nil, screen: .mouse).hint, hintState(.stopGamepad))
    }

    // MARK: - What puts a hint to rest

    func testOpeningSupportDishPutsTheHeartsHintToRest() {
        XCTAssertEqual(learned(.push(.support)), .supportDish)
        XCTAssertNil(learned(.push(.help)))
        XCTAssertEqual(learned(.show(.support, in: .controllers)), .supportDish, "an iPad shows it beside the list")
        XCTAssertNil(learned(.show(.help, in: .settings)))
    }

    /// Add a controller, or a first run's walk that bound one.
    func testAddingOrBindingAControllerPutsItsHintToRest() {
        XCTAssertEqual(learned(.openSetup(.addController)), .addController)
        let walking = reduceNavigation(NavigationState(), .openSetup(.firstRun)).state
        XCTAssertEqual(learned(.setupEnded(.bound), from: walking), .addController)
        XCTAssertNil(learned(.setupEnded(.skipped), from: walking))
        XCTAssertNil(learned(.setupEnded(.bound)), "no walk was up")
        XCTAssertNil(learned(.openSetup(.guide)))
    }

    func testStoppingTheGamepadPutsTheWayOutsHintToRest() {
        let playing = reduceNavigation(NavigationState(), .openPlay(.gamepad)).state
        XCTAssertEqual(learned(.closePlay, from: playing), .stopGamepad)
        XCTAssertNil(learned(.closePlay), "nothing was playing")
        XCTAssertNil(learned(.coverDismissed, from: playing), "the system closed it, not the person")
    }

    func testDimmingPutsItsHintToRestOnlyWhenTheDimRose() {
        XCTAssertEqual(learned(.dim), .dim)
        let playing = reduceNavigation(NavigationState(), .openPlay(.gamepad)).state
        XCTAssertNil(learned(.dim, from: playing), "the dim is refused over play")
    }

    func testMovingAroundTeachesNothing() {
        let events: [NavigationEvent] = [.select(.settings), .push(.deviceName), .pop, .openPlay(.mouse), .wake, .openSheet(.addByAddress)]
        XCTAssertEqual(events.compactMap { learned($0) }, [])
    }
}
