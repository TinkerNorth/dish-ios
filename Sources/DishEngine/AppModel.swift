// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation
import Observation

/// The composition root: it holds every store and seam and vends the facts
/// the shell draws. Intents live in extensions by topic and are the only
/// thing a view calls. The controllers come from the GameController bridge,
/// the PCs and the session from the satellite pool.
@MainActor
@Observable
package final class AppModel {
    package let onboarding: OnboardingPreferenceStore
    let appearance: AppearancePreferenceStore
    let device: DevicePreferenceStore
    let streaming: StreamingPreferenceStore
    let clock: ClockSource
    package let localNetwork: any LocalNetworkAccess
    /// The pads iOS sees and their stores.
    package let pads: ControllerStack
    /// The satellite pool and the bindings.
    package let network: NetworkStack
    /// The App Store, for Support Dish.
    let tips: any TipStore
    /// What the Diagnostics page reads, re-read once a second while it shows.
    package let diagnostics: DiagnosticsSource
    /// The flight recorder's lines.
    package let diagnosticsLog: DiagnosticsLogStore
    /// Feeds the flight recorder from the rows and the controllers.
    @ObservationIgnored let recorder: DiagnosticsRecorder
    /// The clipboard, the scene's to fill.
    let pasteboard: any Pasteboard
    let setupSource = StateSource<SetupState?>(initial: nil)
    let supportSource = StateSource<SupportFacts>(initial: .initial)
    /// The on-screen controller's slot: its touches, its resend loop, its motion.
    package let onScreen: OnScreenPad
    /// The play screen on display; nil while none is.
    let playSource = StateSource<PlayScreen?>(initial: nil)
    /// Whether the on-screen controller is one of the controllers.
    let onScreenListed = StateSource<Bool>(initial: false)
    /// Each pad's route, from the bindings and the live clients.
    @ObservationIgnored let routing = InputRouting()
    /// The satellites' return paths to the pads bound on them.
    @ObservationIgnored let returnPaths: ReturnPathRouter
    /// The Moonlight hosts' feedback onto the pads bound to them.
    @ObservationIgnored let moonlightFeedback: MoonlightFeedbackRouter
    /// What each Moonlight host was last asked to carry, so an unrelated
    /// change converges nothing.
    @ObservationIgnored var lastDesired: [String: [MoonlightPadRequest]] = [:]
    /// The satellite whose pairing card is open.
    package internal(set) var pairingTarget: DiscoveredServer?
    /// The Moonlight host that minted a PIN for the person to type into it;
    /// the hosts page shows the card in its row.
    package internal(set) var moonlightPin: MoonlightPinPrompt?
    /// The last thing a Moonlight host had to say; the hosts page words it.
    package internal(set) var lastMoonlightEvent: MoonlightConnectionEvent?
    /// The last thing the pool had to say: a failure, or a satellite that
    /// wants a PIN. The pages word it.
    package internal(set) var lastConnectionEvent: ConnectionEvent?
    /// The one bind in flight and where it stands.
    package internal(set) var bindingProgress = ApplyProgress.idle
    /// The pad and the PC of the last bind asked for; the apply fact names them.
    var applyTarget: ApplyTarget?
    @ObservationIgnored var applyWatch: ApplyWatch?
    /// The PC the person typed by its address this run.
    package internal(set) var addedByAddress: DiscoveredServer?

    package init(
        onboarding: OnboardingPreferenceStore,
        appearance: AppearancePreferenceStore,
        device: DevicePreferenceStore,
        streaming: StreamingPreferenceStore,
        clock: ClockSource,
        localNetwork: any LocalNetworkAccess,
        pads: ControllerStack,
        network: NetworkStack,
        tips: any TipStore,
        motionSensor: any MotionSensor,
        resendTicker: any Ticker,
        diagnostics: DiagnosticsSource = DiagnosticsSource(ticker: TimerTicker()),
        pasteboard: any Pasteboard = InertPasteboard()
    ) {
        self.onboarding = onboarding
        self.appearance = appearance
        self.device = device
        self.streaming = streaming
        self.clock = clock
        self.localNetwork = localNetwork
        self.pads = pads
        self.network = network
        self.tips = tips
        self.diagnostics = diagnostics
        self.pasteboard = pasteboard
        let log = DiagnosticsLogStore()
        diagnosticsLog = log
        recorder = DiagnosticsRecorder(store: log)
        returnPaths = ReturnPathRouter(feedback: pads.source.feedback)
        moonlightFeedback = MoonlightFeedbackRouter(feedback: pads.source.feedback)
        onScreen = OnScreenPad(feed: pads.source.processor.feed(for: onScreenSlotId), ticker: resendTicker, sensor: motionSensor)
        applyStoredDeadzones()
        pads.source.processor.setDeadzones(deviceId: onScreenSlotId, GamepadInputProcessor.Deadzones())
        wireNetwork()
        wireDiagnostics()
        wireMoonlight()
        observeBindingMemory()
        restoreStandingBindings()
    }

    /// Every store over the same defaults, the wall clock, the pads iOS
    /// sees, the satellite pool with its keys in the Keychain, the Bonjour
    /// scan as the Local Network seam, the App Store and the phone's sensors.
    package convenience init(
        defaults: UserDefaults,
        clock: ClockSource = ClockSource(ticker: TimerTicker(), now: Date.init),
        localNetwork: (any LocalNetworkAccess)? = nil,
        keyStore: any KeyStore = KeychainKeyStore(),
        pins: CertPins = CertPins(file: CertPins.defaultFile()),
        tips: any TipStore = StoreKitTipStore(),
        controllerSource: any ControllerSource = GameControllerInput(),
        motionSensor: any MotionSensor = DeviceMotionSensor(),
        resendTicker: any Ticker = TimerTicker(),
        diagnostics: DiagnosticsSource = DiagnosticsSource(ticker: TimerTicker()),
        pasteboard: any Pasteboard = InertPasteboard(),
        deviceKind: DeviceKind = .phone
    ) {
        let device = DevicePreferenceStore(defaults: defaults)
        let network = NetworkStack(defaults: defaults, keyStore: keyStore, pins: pins) { wireDeviceName(device.state, on: deviceKind) }
        self.init(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: device,
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: clock,
            localNetwork: localNetwork ?? BonjourLocalNetworkAccess(wifi: network.wifi),
            pads: ControllerStack(source: controllerSource, defaults: defaults),
            network: network,
            tips: tips,
            motionSensor: motionSensor,
            resendTicker: resendTicker,
            diagnostics: diagnostics,
            pasteboard: pasteboard
        )
        Self.mintMoonlightIdentity(into: network)
    }

    /// The dish's Moonlight identity, RSA-2048 born in the keychain: minted
    /// off the main actor, since a first launch generates a key, then
    /// adopted by the manager and the gateway it pairs and calls through.
    private static func mintMoonlightIdentity(into network: NetworkStack) {
        guard let gateway = network.moonlightGateway else { return }
        let manager = network.moonlight
        Task.detached(priority: .utility) {
            guard let identity = MoonlightIdentityStore.loadOrCreate() else { return }
            await MainActor.run {
                manager.adoptIdentity(identity)
                gateway.adoptIdentity(identity)
            }
        }
    }

    /// The setup walk on screen; nil while the cover is down.
    package var setup: SetupState? {
        setupSource.state
    }

    package var shellFacts: ShellFacts {
        ShellFacts(
            controllers: controllerFacts,
            attachedPads: attachedPadFacts,
            paired: pairedFacts,
            found: foundFacts,
            scanning: network.wifi.isScanning,
            session: sessionFact,
            localNetwork: localNetwork.status,
            preferences: preferencesFacts,
            now: clock.state,
            setup: setup,
            support: supportSource.state,
            play: playFacts,
            diagnostics: diagnostics.state,
            diagnosticsEvents: diagnosticsLog.state,
            apply: applyFact,
            addedByAddress: addedByAddress?.id,
            deadzones: pads.deadzones.state,
            forwarding: pads.features.flags
        )
    }

    private var preferencesFacts: PreferencesFacts {
        let streaming = streaming.state
        return PreferencesFacts(
            deviceName: device.state,
            keepScreenOn: streaming.keepScreenOn,
            dimAfter: streaming.dimAfter,
            appearance: appearance.state
        )
    }
}
