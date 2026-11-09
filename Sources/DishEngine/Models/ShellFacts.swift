// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// Everything the shell draws from, in one value: the app's mappers word
/// it, the engine never does.
package struct ShellFacts: Equatable {
    package let controllers: [ControllerFact]
    /// The pads attached to this iPhone right now, bound or not; setup
    /// offers them first. Empty until the controller bridge lands.
    package let attachedPads: [AttachedPadFact]
    package let paired: [ConnectionFact]
    package let found: [ConnectionFact]
    /// Whether discovery is looking right now.
    package let scanning: Bool
    /// Nil while nothing streams.
    package let session: SessionFact?
    package let localNetwork: LocalNetworkStatus
    package let preferences: PreferencesFacts
    /// The wall clock, moving once a minute while a page that words a time
    /// is on screen.
    package let now: Date
    /// The setup walk on screen; nil while the cover is down.
    package let setup: SetupState?
    /// Support Dish: what the App Store sells and where a tip stands.
    package let support: SupportFacts

    package init(
        controllers: [ControllerFact],
        attachedPads: [AttachedPadFact],
        paired: [ConnectionFact],
        found: [ConnectionFact],
        scanning: Bool,
        session: SessionFact?,
        localNetwork: LocalNetworkStatus,
        preferences: PreferencesFacts,
        now: Date,
        setup: SetupState?,
        support: SupportFacts = .initial
    ) {
        self.controllers = controllers
        self.attachedPads = attachedPads
        self.paired = paired
        self.found = found
        self.scanning = scanning
        self.session = session
        self.localNetwork = localNetwork
        self.preferences = preferences
        self.now = now
        self.setup = setup
        self.support = support
    }
}
