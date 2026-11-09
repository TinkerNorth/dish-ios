// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation

/// Facts for the mapper tests: the engine's defaults with one thing changed
/// at a time.
enum FactsFixture {
    /// The wall clock every fixture reads.
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let preferences = PreferencesFacts(deviceName: "", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system)

    static func shell(
        controllers: [ControllerFact] = [],
        attachedPads: [AttachedPadFact] = [],
        paired: [ConnectionFact] = [],
        found: [ConnectionFact] = [],
        scanning: Bool = false,
        session: SessionFact? = nil,
        localNetwork: LocalNetworkStatus = .unknown,
        preferences: PreferencesFacts = preferences,
        now: Date = now,
        setup: SetupState? = nil
    ) -> ShellFacts {
        ShellFacts(
            controllers: controllers,
            attachedPads: attachedPads,
            paired: paired,
            found: found,
            scanning: scanning,
            session: session,
            localNetwork: localNetwork,
            preferences: preferences,
            now: now,
            setup: setup
        )
    }

    static func streaming(pads: Int = 3, latencyMs: Int? = 4) -> SessionFact {
        SessionFact(pcName: "Living Room PC", pads: pads, latencyMs: latencyMs, phase: .streaming)
    }

    static let stopped = SessionFact(pcName: "Living Room PC", pads: 3, latencyMs: 4, phase: .stoppedResponding)
}
