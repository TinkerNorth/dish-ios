// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
@testable import DishEngine

/// A ticker the test fires by hand, recording how it was started.
@MainActor
final class ManualTicker: Ticker {
    private(set) var starts: [TimeInterval] = []
    private(set) var stops = 0
    private var tick: (@MainActor () -> Void)?

    var running: Bool {
        tick != nil
    }

    func start(every seconds: TimeInterval, _ tick: @escaping @MainActor () -> Void) {
        starts.append(seconds)
        self.tick = tick
    }

    func stop() {
        stops += 1
        tick = nil
    }

    func fire() {
        tick?()
    }
}

/// A clock the test moves by hand.
@MainActor
final class ManualNow {
    var date = Date(timeIntervalSince1970: 1_800_000_000)

    func read() -> Date {
        date
    }
}
