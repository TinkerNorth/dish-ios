// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// Diagnostics › a controller's bench: each test the pad's path carries,
/// run from this device alone, and the person's answer.
package extension AppModel {

    var benchFacts: BenchFacts {
        BenchFacts(controllers: controllerFacts, reach: benchReaches, bench: bench.state)
    }

    /// Runs the test where the pad's path carries it, whatever the pad's
    /// switches say: the bench proves the hardware, not the forwarding.
    func runBenchTest(_ test: BenchTest, slotId: String) {
        guard let reach = benchReaches[slotId], benchOffers(test, reach: reach) else { return }
        bench.start(test, slotId: slotId)
    }

    /// "Did it work?" for the test the pad ran last.
    func answerBenchTest(slotId: String, worked: Bool) {
        bench.answer(slotId: slotId, worked: worked)
    }
}

extension AppModel {

    /// Every listed controller's reach, the on-screen controller's with them.
    var benchReaches: [String: BenchReach] {
        let listed = pads.slots.map { ($0.id, benchReach($0)) } + [(onScreenSlotId, onScreenBenchReach(phoneHaptics: phoneHaptics))]
        return Dictionary(listed) { first, _ in first }
    }
}
