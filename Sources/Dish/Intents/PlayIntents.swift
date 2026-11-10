// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import AppIntents

// Each intent is public because the app target's App Shortcuts provider
// names it: App Intents reads a provider only from the app's own target.

/// Open the gamepad: the on-screen gamepad, in landscape.
public struct OpenGamepadIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open the gamepad"
    public static let description = IntentDescription("Opens the on-screen gamepad in landscape.")
    public static let supportedModes: IntentModes = .foreground

    @Dependency private var router: IntentRouter

    public init() {}

    /// What the intent asks of the app.
    var event: NavigationEvent {
        .openPlay(.gamepad)
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        router.post(event)
        return .result()
    }
}

/// Open the touchpad: the on-screen touchpad, in landscape.
public struct OpenTouchpadIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open the touchpad"
    public static let description = IntentDescription("Opens the on-screen touchpad in landscape.")
    public static let supportedModes: IntentModes = .foreground

    @Dependency private var router: IntentRouter

    public init() {}

    var event: NavigationEvent {
        .openPlay(.touchpad)
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        router.post(event)
        return .result()
    }
}

/// Open the mouse: the on-screen mouse, in landscape.
public struct OpenMouseIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open the mouse"
    public static let description = IntentDescription("Opens the on-screen mouse in landscape.")
    public static let supportedModes: IntentModes = .foreground

    @Dependency private var router: IntentRouter

    public init() {}

    var event: NavigationEvent {
        .openPlay(.mouse)
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        router.post(event)
        return .result()
    }
}

/// Dim the screen: the low-power dim, which a tap wakes.
public struct DimScreenIntent: AppIntent {
    public static let title: LocalizedStringResource = "Dim the screen"
    public static let description = IntentDescription("Dims the screen while a controller streams.")
    public static let supportedModes: IntentModes = .foreground

    @Dependency private var router: IntentRouter

    public init() {}

    var event: NavigationEvent {
        .dim
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        router.post(event)
        return .result()
    }
}
