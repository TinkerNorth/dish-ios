// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import AppIntents

/// Connect to a PC: one of the paired PCs, which the app reaches for and
/// shows on its page.
public struct ConnectToPCIntent: AppIntent {
    public static let title: LocalizedStringResource = "Connect to a PC"
    public static let description = IntentDescription("Connects to one of your paired PCs.")
    public static let supportedModes: IntentModes = .foreground

    @Parameter(title: "PC")
    var pc: PCEntity

    @Dependency private var router: IntentRouter

    public init() {}

    init(pc: PCEntity) {
        self.pc = pc
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Connect to \(\.$pc)")
    }

    /// What the intent asks of the app.
    var event: NavigationEvent {
        .connectTo(id: pc.id)
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        router.post(event)
        return .result()
    }
}

/// A paired PC, as Connect to PC offers it.
struct PCEntity: AppEntity, Equatable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "PC"
    static let defaultQuery = PCQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// The paired PCs, read from the running app.
struct PCQuery: EntityQuery {
    @Dependency private var router: IntentRouter

    @MainActor
    func entities(for identifiers: [PCEntity.ID]) async throws -> [PCEntity] {
        router.pcs.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [PCEntity] {
        router.pcs
    }
}
