// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// A model whose clock the test drives.
@MainActor
private struct ClockedModel {
    let model: AppModel
    let ticker = ManualTicker()
    let now = ManualNow()

    init(_ test: XCTestCase) throws {
        let defaults = try TestDefaults.fresh(test)
        model = AppModel(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: ticker, now: now.read),
            localNetwork: RecordedLocalNetworkAccess(),
            pads: ControllerStack(source: FakeControllerSource(), defaults: defaults),
            network: TestNetwork.stack(defaults: defaults),
            tips: RecordedTipStore(shelf: .success([])),
            motionSensor: FakeMotionSensor(),
            resendTicker: ManualTicker()
        )
    }
}

@MainActor
final class AppModelPagesTests: XCTestCase {

    func testConnectionsAppearingStartsTheClockAndATickMovesNow() throws {
        let clocked = try ClockedModel(self)
        clocked.model.pageAppeared(.connections)
        XCTAssertEqual(clocked.model.shellFacts.now, clocked.now.date)
        clocked.now.date = clocked.now.date.addingTimeInterval(60)
        clocked.ticker.fire()
        XCTAssertEqual(clocked.model.shellFacts.now, clocked.now.date)
    }

    func testConnectionsDisappearingStopsTheClock() throws {
        let clocked = try ClockedModel(self)
        clocked.model.pageAppeared(.connections)
        clocked.model.pageDisappeared(.connections)
        XCTAssertFalse(clocked.ticker.running)
    }

    func testTheDimRunsTheClockWhileItIsUp() throws {
        let clocked = try ClockedModel(self)
        clocked.model.pageAppeared(.dim)
        XCTAssertTrue(clocked.ticker.running)
        clocked.model.pageDisappeared(.dim)
        XCTAssertFalse(clocked.ticker.running)
    }

    func testTheClockIsIdleUntilAPageAsksForIt() throws {
        let clocked = try ClockedModel(self)
        XCTAssertEqual(clocked.ticker.starts, [])
    }
}
