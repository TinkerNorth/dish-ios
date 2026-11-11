// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

@MainActor
final class OnboardingPreferenceStoreTests: XCTestCase {

    func testAFreshInstallHasNotSeenTheWelcome() throws {
        let store = try OnboardingPreferenceStore(defaults: TestDefaults.fresh(self))
        XCTAssertFalse(store.state.welcomeCompleted)
    }

    func testTheStoredFlagIsReadUnderTheFleetsKey() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set(true, forKey: "onboarding_welcome_completed")
        XCTAssertTrue(OnboardingPreferenceStore(defaults: defaults).state.welcomeCompleted)
    }

    func testCompletingTheWelcomePersistsAndPublishes() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = OnboardingPreferenceStore(defaults: defaults)
        store.markWelcomeComplete()
        XCTAssertTrue(store.state.welcomeCompleted)
        XCTAssertTrue(defaults.bool(forKey: OnboardingPreferenceStore.welcomeCompletedKey))
        XCTAssertTrue(OnboardingPreferenceStore(defaults: defaults).state.welcomeCompleted, "a relaunch reads it back")
    }

    func testCompletingTwiceWritesOnce() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = OnboardingPreferenceStore(defaults: defaults)
        store.markWelcomeComplete()
        defaults.removeObject(forKey: OnboardingPreferenceStore.welcomeCompletedKey)
        store.markWelcomeComplete()
        XCTAssertFalse(defaults.bool(forKey: OnboardingPreferenceStore.welcomeCompletedKey), "a repeat set is a no-op")
    }

    func testAFreshInstallHasNotSeenTheLocalNetworkPrimer() throws {
        let store = try OnboardingPreferenceStore(defaults: TestDefaults.fresh(self))
        XCTAssertFalse(store.state.localNetworkPrimed)
    }

    func testThePrimedFlagIsReadUnderDishMacsKey() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set(true, forKey: "local_network_primed")
        XCTAssertTrue(OnboardingPreferenceStore(defaults: defaults).state.localNetworkPrimed)
        XCTAssertFalse(OnboardingPreferenceStore(defaults: defaults).state.welcomeCompleted, "the two flags are separate")
    }

    func testMarkingThePrimerSeenPersistsPublishesAndWritesOnce() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = OnboardingPreferenceStore(defaults: defaults)
        store.markLocalNetworkPrimed()
        XCTAssertTrue(store.state.localNetworkPrimed)
        XCTAssertTrue(OnboardingPreferenceStore(defaults: defaults).state.localNetworkPrimed, "a relaunch reads it back")
        defaults.removeObject(forKey: OnboardingPreferenceStore.localNetworkPrimedKey)
        store.markLocalNetworkPrimed()
        XCTAssertFalse(defaults.bool(forKey: OnboardingPreferenceStore.localNetworkPrimedKey), "a repeat set is a no-op")
    }
}
