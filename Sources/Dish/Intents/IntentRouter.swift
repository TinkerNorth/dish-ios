// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import Foundation

/// Where an App Intent lands in the running app. The scene builds it over
/// its navigation and its model's paired PCs and hands it to App Intents;
/// an intent posts a navigation event through it, and Connect to PC reads
/// the PCs it can name. The engine knows nothing of either.
@MainActor
final class IntentRouter {
    private let send: (NavigationEvent) -> Void
    private let paired: () -> [ConnectionFact]
    private var registered = false

    init(send: @escaping (NavigationEvent) -> Void, paired: @escaping () -> [ConnectionFact]) {
        self.send = send
        self.paired = paired
    }

    /// Hands this router to App Intents through `add`, once. An intent
    /// resolves its router as it starts, and a registration made while it
    /// runs takes that one away, so the intent traps.
    func register(with add: (IntentRouter) -> Void) {
        guard !registered else { return }
        registered = true
        add(self)
    }

    func post(_ event: NavigationEvent) {
        send(event)
    }

    /// The paired PCs, as Connect to PC offers them.
    var pcs: [PCEntity] {
        paired().map(pcEntity)
    }
}

/// A paired PC as App Intents names it: its name, or its address when it
/// never advertised one, as its Connections row does.
func pcEntity(_ connection: ConnectionFact) -> PCEntity {
    PCEntity(id: connection.id, name: connectionTitle(connection))
}
