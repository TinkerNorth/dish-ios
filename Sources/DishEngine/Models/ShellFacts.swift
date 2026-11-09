// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Everything the shell draws from, in one value: the app's mappers word
/// it, the engine never does.
package struct ShellFacts: Equatable {
    package let controllers: [ControllerFact]
    package let paired: [ConnectionFact]
    package let found: [ConnectionFact]
    /// Whether discovery is looking right now.
    package let scanning: Bool
    /// Nil while nothing streams.
    package let session: SessionFact?
    package let localNetwork: LocalNetworkStatus
    package let preferences: PreferencesFacts

    package init(
        controllers: [ControllerFact],
        paired: [ConnectionFact],
        found: [ConnectionFact],
        scanning: Bool,
        session: SessionFact?,
        localNetwork: LocalNetworkStatus,
        preferences: PreferencesFacts
    ) {
        self.controllers = controllers
        self.paired = paired
        self.found = found
        self.scanning = scanning
        self.session = session
        self.localNetwork = localNetwork
        self.preferences = preferences
    }
}
