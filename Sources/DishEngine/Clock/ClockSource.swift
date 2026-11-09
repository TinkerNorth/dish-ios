// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// Calls back on the main actor every so often until stopped.
@MainActor
package protocol Ticker: AnyObject {
    func start(every seconds: TimeInterval, _ tick: @escaping @MainActor () -> Void)
    func stop()
}

/// The production ticker: a repeating `Timer` on the main run loop.
@MainActor
package final class TimerTicker: Ticker {
    private var timer: Timer?

    package init() {}

    package func start(every seconds: TimeInterval, _ tick: @escaping @MainActor () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { _ in
            MainActor.assumeIsolated(tick)
        }
    }

    package func stop() {
        timer?.invalidate()
        timer = nil
    }
}

/// The wall clock as a fact: a page that words a time ("seen yesterday")
/// starts it while on screen, and it republishes the date every minute.
@MainActor
package final class ClockSource {
    static let tickSeconds: TimeInterval = 60

    private let ticker: any Ticker
    private let now: @MainActor () -> Date
    private let source: StateSource<Date>
    private var running = false

    package var state: Date {
        source.state
    }

    package init(ticker: any Ticker, now: @escaping @MainActor () -> Date) {
        self.ticker = ticker
        self.now = now
        source = StateSource(initial: now())
    }

    package func start() {
        guard !running else { return }
        running = true
        source.setState(now())
        ticker.start(every: Self.tickSeconds, tick)
    }

    package func stop() {
        guard running else { return }
        running = false
        ticker.stop()
    }

    private func tick() {
        source.setState(now())
    }
}
