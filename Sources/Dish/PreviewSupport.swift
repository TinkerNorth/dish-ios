// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation

/// The windows the previews are drawn in, as the scene's reader would see
/// them: a preview names the device it stands for, whatever the canvas is.
enum PreviewWindow {
    static let phoneOnItsSide = WindowFacts(width: .compact, height: .compact, shape: .landscape)
    static let iPadOnItsSide = WindowFacts(width: .regular, height: .regular, shape: .landscape)
    static let iPadUpright = WindowFacts(width: .regular, height: .regular, shape: .portrait)
}

/// What the setup previews are drawn over: the boards' pads and PCs, and a
/// model walked to a step. Previews only; the app builds its own in the scene.
@MainActor
enum PreviewSetup {
    static let nothingSeen = SetupInputs(detectedPads: [], found: [], scanning: false, localNetwork: .unknown)

    /// The previews' own defaults, so a preview never writes the app's.
    private static let defaults = UserDefaults(suiteName: "com.tinkernorth.dish.ios.previews") ?? UserDefaults()

    /// A model with no walk and the stores' defaults.
    static func emptyModel() -> AppModel {
        AppModel(defaults: defaults)
    }

    static let padsAndPCs = SetupInputs(
        detectedPads: [
            SetupPadInput(id: "pad-1", name: "DualSense", link: .usbC, batteryPercent: 84, family: .dualSense)
        ],
        found: [
            SetupPCInput(id: "lr", name: "Living Room PC", address: "192.168.1.24", kind: .satellite, paired: true),
            SetupPCInput(id: "office", name: "Office PC", address: "192.168.1.31", kind: .satellite, paired: false)
        ],
        scanning: true,
        localNetwork: .allowed
    )

    static let refused = SetupInputs(detectedPads: [], found: [], scanning: false, localNetwork: .denied)

    static let reviewDraft = SetupDraft(
        input: .detectedPad(id: "pad-1", family: .dualSense),
        destination: .satellite(id: "lr"),
        emulateAs: .dualSense,
        motion: true
    )

    /// A navigation whose setup hooks do nothing.
    static func navigation() -> NavigationStore {
        let onboarding = OnboardingPreferenceStore(defaults: UserDefaults())
        return NavigationStore(onboarding: onboarding, startSetup: ignoreEntry, endSetup: ignoreEnd)
    }

    /// A navigation on the tabs, the welcome seen, so a shell preview opens
    /// on Controllers.
    static func tabsNavigation() -> NavigationStore {
        let onboarding = OnboardingPreferenceStore(defaults: defaults)
        onboarding.markWelcomeComplete()
        return NavigationStore(onboarding: onboarding, startSetup: ignoreEntry, endSetup: ignoreEnd)
    }

    private static func ignoreEntry(_ entry: SetupEntry) {}

    private static func ignoreEnd() {}

    /// A model whose walk stands on `step`, reached through its intents.
    static func model(at step: SetupStep) -> AppModel {
        let model = emptyModel()
        model.startSetup(start(for: step))
        events(to: step).forEach { $0(model) }
        return model
    }

    private static func start(for step: SetupStep) -> SetupStart {
        switch step {
        case .welcome: .welcome
        case .input, .localNetworkPrimer, .pickPC, .review: .input
        }
    }

    private static func events(to step: SetupStep) -> [(AppModel) -> Void] {
        switch step {
        case .welcome, .input: []
        case .localNetworkPrimer: [pickWired]
        case .pickPC: [pickWired, allow]
        case .review: [pickWired, addByAddress]
        }
    }

    private static func pickWired(_ model: AppModel) {
        model.pickSetupInput(.wired)
    }

    private static func allow(_ model: AppModel) {
        model.answerLocalNetwork(allowed: true)
    }

    private static func addByAddress(_ model: AppModel) {
        model.pickSetupDestination(.byAddress)
    }
}
