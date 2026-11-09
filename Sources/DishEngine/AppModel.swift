// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation
import Observation

/// The composition root: it builds the stores and the seams once and is the
/// only engine object a view reaches. Intents live in extensions by topic.
@MainActor
@Observable
package final class AppModel {
    package let localNetwork: any LocalNetworkAccess
    package let bindings: BindingRequests
    let setupSource = StateSource<SetupState?>(initial: nil)

    /// The setup walk on screen; nil while the cover is down.
    package var setup: SetupState? {
        setupSource.state
    }

    package init(
        localNetwork: any LocalNetworkAccess = RecordedLocalNetworkAccess(),
        bindings: BindingRequests = BindingRequests()
    ) {
        self.localNetwork = localNetwork
        self.bindings = bindings
    }
}
