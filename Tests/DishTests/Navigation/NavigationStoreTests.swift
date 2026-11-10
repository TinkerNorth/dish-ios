// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import XCTest
@testable import Dish

/// What the store asked of the model.
@MainActor
private final class SetupLog {
    private(set) var started: [SetupEntry] = []
    private(set) var ended = 0

    func start(_ entry: SetupEntry) {
        started.append(entry)
    }

    func end() {
        ended += 1
    }
}

/// What the store asked of the model's play screens.
@MainActor
private final class PlayLog {
    private(set) var opened: [PlayScreen] = []
    private(set) var closed = 0

    func open(_ screen: PlayScreen) {
        opened.append(screen)
    }

    func close() {
        closed += 1
    }
}

/// What the store asked of the model's pairing.
@MainActor
private final class PairingLog {
    private(set) var begun: [String] = []
    private(set) var cancelled: [String] = []

    func begin(_ serverId: String) {
        begun.append(serverId)
    }

    func cancel(_ serverId: String) {
        cancelled.append(serverId)
    }
}

@MainActor
final class NavigationStoreTests: XCTestCase {

    private func store(_ onboarding: OnboardingPreferenceStore, log: SetupLog = SetupLog()) -> NavigationStore {
        NavigationStore(onboarding: onboarding, startSetup: log.start, endSetup: log.end)
    }

    private func freshDefaults() throws -> UserDefaults {
        let suite = "com.tinkernorth.dish.ios.tests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    private func completedOnboarding() throws -> OnboardingPreferenceStore {
        let onboarding = try OnboardingPreferenceStore(defaults: freshDefaults())
        onboarding.markWelcomeComplete()
        return onboarding
    }

    func testAFirstRunOpensUnderTheSetupCoverAndStartsTheWalk() throws {
        let log = SetupLog()
        let store = try store(OnboardingPreferenceStore(defaults: freshDefaults()), log: log)
        XCTAssertEqual(store.state.cover, .setup(.firstRun))
        XCTAssertEqual(store.state.tab, .controllers)
        XCTAssertEqual(log.started, [.firstRun])
    }

    func testACompletedWelcomeOpensOnTheTabs() throws {
        let log = SetupLog()
        XCTAssertNil(try store(completedOnboarding(), log: log).state.cover)
        XCTAssertEqual(log.started, [])
    }

    func testSkippingSetupPersistsTheWelcomeAsSeenAndEndsTheWalk() throws {
        let onboarding = try OnboardingPreferenceStore(defaults: freshDefaults())
        let log = SetupLog()
        let store = store(onboarding, log: log)
        store.send(.setupEnded(.skipped))
        XCTAssertNil(store.state.cover)
        XCTAssertTrue(onboarding.state.welcomeCompleted)
        XCTAssertEqual(log.ended, 1)
    }

    func testOpeningSetupLaterStartsTheWalkAtItsEntry() throws {
        let log = SetupLog()
        let store = try store(completedOnboarding(), log: log)
        store.send(.openSetup(.addController))
        XCTAssertEqual(store.state.cover, .setup(.addController))
        XCTAssertEqual(log.started, [.addController])
    }

    func testTheBindingsSendEvents() throws {
        let store = try store(completedOnboarding())
        store.tab.wrappedValue = .settings
        XCTAssertEqual(store.state.tab, .settings)
        store.path(of: .settings).wrappedValue = [.deviceName]
        XCTAssertEqual(store.state.path(of: .settings), [.deviceName])
        store.send(.openSetup(.guide))
        store.cover.wrappedValue = nil
        XCTAssertNil(store.state.cover, "a system dismissal is a skip")
        XCTAssertEqual(store.state.tab, .controllers)
    }

    func testPlayOpensAndClosesTheModelsScreens() throws {
        let plays = PlayLog()
        let store = try NavigationStore(
            onboarding: completedOnboarding(),
            startSetup: SetupLog().start,
            endSetup: SetupLog().end,
            startPlay: plays.open,
            endPlay: plays.close
        )
        store.send(.openPlay(.gamepad))
        store.send(.openPlay(.touchpad))
        XCTAssertEqual(store.state.cover, .play(.touchpad))
        store.cover.wrappedValue = nil
        XCTAssertNil(store.state.cover, "a system dismissal closes play")
        XCTAssertEqual(plays.opened, [.gamepad, .touchpad])
        XCTAssertEqual(plays.closed, 1)
    }

    func testTheCoverBindingIgnoresARedundantNil() throws {
        let store = try store(completedOnboarding())
        store.send(.select(.settings))
        store.cover.wrappedValue = nil
        XCTAssertEqual(store.state.tab, .settings, "nothing was lowered, so nothing moved")
    }

    private func store(_ onboarding: OnboardingPreferenceStore, pairing: PairingLog) -> NavigationStore {
        NavigationStore(
            onboarding: onboarding,
            startSetup: SetupLog().start,
            endSetup: SetupLog().end,
            beginPairing: pairing.begin,
            cancelPairing: pairing.cancel
        )
    }

    func testTheSheetBindingsPresentFromTheTabsOrTheCoverAndADismissalCloses() throws {
        let pairing = PairingLog()
        let store = try store(completedOnboarding(), pairing: pairing)
        store.send(.openSheet(.pair(serverId: "den")))
        XCTAssertEqual(store.tabsSheet.wrappedValue, .pair(serverId: "den"))
        XCTAssertNil(store.setupSheet.wrappedValue)
        XCTAssertEqual(pairing.begun, ["den"])
        store.tabsSheet.wrappedValue = nil
        XCTAssertNil(store.state.sheet, "a swipe down closes the sheet")
        XCTAssertEqual(pairing.cancelled, ["den"])
        store.send(.openSetup(.guide))
        store.send(.openSheet(.addByAddress))
        XCTAssertEqual(store.setupSheet.wrappedValue, .addByAddress)
        XCTAssertNil(store.tabsSheet.wrappedValue)
        store.setupSheet.wrappedValue = nil
        XCTAssertNil(store.state.sheet)
    }

    func testASplitListsSelectionShowsItsPageAndClearingItClosesTheDetail() throws {
        let store = try store(completedOnboarding())
        let selection = store.listSelection(of: .controllers)
        XCTAssertNil(selection.wrappedValue)
        selection.wrappedValue = .controller(id: "a")
        selection.wrappedValue = .controller(id: "b")
        XCTAssertEqual(store.state.path(of: .controllers), [.controller(id: "b")], "a second row replaces the first")
        XCTAssertEqual(selection.wrappedValue, .controller(id: "b"))
        selection.wrappedValue = nil
        XCTAssertEqual(store.state.path(of: .controllers), [])
    }

    func testTheDetailColumnHoldsWhatIsPushedOverThePageItsListOpened() throws {
        let store = try store(completedOnboarding())
        store.send(.show(.controller(id: "a"), in: .controllers))
        let detail = store.detailPath(of: .controllers)
        XCTAssertEqual(detail.wrappedValue, [])
        store.send(.push(.support))
        XCTAssertEqual(detail.wrappedValue, [.support])
        detail.wrappedValue = []
        XCTAssertEqual(store.state.path(of: .controllers), [.controller(id: "a")], "a pop in the detail stops at the opened page")
    }

    func testTheSheetBindingIgnoresARedundantNil() throws {
        let pairing = PairingLog()
        let store = try store(completedOnboarding(), pairing: pairing)
        store.tabsSheet.wrappedValue = nil
        XCTAssertEqual(pairing.cancelled, [])
    }
}
