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

    func testTheCoverBindingIgnoresARedundantNil() throws {
        let store = try store(completedOnboarding())
        store.send(.select(.settings))
        store.cover.wrappedValue = nil
        XCTAssertEqual(store.state.tab, .settings, "nothing was lowered, so nothing moved")
    }
}
