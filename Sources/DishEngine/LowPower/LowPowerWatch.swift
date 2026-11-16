// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishKernel
import Foundation

/// Where the low-power countdown stands: the seconds left while the last
/// five run, and whether it ended, which is the shell's cue to dim.
package struct LowPowerFact: Equatable {
    package let countdown: Int?
    package let due: Bool

    package static let idle = LowPowerFact(countdown: nil, due: false)

    package init(countdown: Int?, due: Bool) {
        self.countdown = countdown
        self.due = due
    }
}

/// The seconds without a touch on the phone, counted while the shell keeps
/// the watch armed, as `LowPowerFact`.
@MainActor
package final class LowPowerWatch {
    static let tickSeconds: TimeInterval = 1

    private let ticker: any Ticker
    private let source = StateSource<LowPowerFact>(initial: .idle)
    private var delay = DimDelay.never
    private var idleSeconds = 0
    private var ticking = false

    package init(ticker: any Ticker) {
        self.ticker = ticker
    }

    package var state: LowPowerFact {
        source.state
    }

    /// Count towards `delay` while `allowed`; Never, or not allowed, rests.
    package func arm(_ delay: DimDelay, while allowed: Bool) {
        self.delay = delay
        guard allowed, delay != .never else { return rest() }
        guard !ticking else { return publish() }
        ticking = true
        idleSeconds = 0
        publish()
        ticker.start(every: Self.tickSeconds, tick)
    }

    package func rest() {
        guard ticking else { return }
        ticker.stop()
        ticking = false
        idleSeconds = 0
        source.setState(.idle)
    }

    package func touched() {
        guard ticking else { return }
        idleSeconds = 0
        publish()
    }

    /// The shell took the due countdown: the count starts over.
    package func handled() {
        touched()
    }

    private func tick() {
        idleSeconds += 1
        publish()
    }

    private func publish() {
        source.setState(lowPowerFact(delay: delay, idleSeconds: idleSeconds))
    }
}

/// The seconds a countdown shows before the dim is due.
let lowPowerCountdownSeconds = 5

/// Where the countdown stands after `idleSeconds` without a touch against
/// `delay`: the last five seconds show, and at zero the dim is due.
package func lowPowerFact(delay: DimDelay, idleSeconds: Int) -> LowPowerFact {
    let left = delay.rawValue - idleSeconds
    let counting = (1 ... lowPowerCountdownSeconds).contains(left)
    return LowPowerFact(countdown: counting ? left : nil, due: left <= 0)
}
