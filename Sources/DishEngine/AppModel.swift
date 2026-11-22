// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation
import Observation

/// The composition root: it holds every store and seam and vends the facts
/// the shell draws. Intents live in extensions by topic and are the only
/// thing a view calls. The controllers come from the GameController bridge
/// and, once the person opts in, the Steam Controllers over Bluetooth; the
/// PCs and the session from the satellite pool.
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
    /// The Diagnostics bench: the tests under way and the answers.
    let bench: BenchStore
    /// Whether the phone has the Taptic Engine the on-screen controller's
    /// rumble plays on.
    let phoneHaptics: Bool
    /// Feeds the flight recorder from the rows and the controllers.
    @ObservationIgnored let recorder: DiagnosticsRecorder
    /// The clipboard, the scene's to fill.
    let pasteboard: any Pasteboard
    /// The controller database in force and its check against the website.
    package let controllerDb: ControllerDbStore
    /// The app and the device, as the scene read them.
    let identity: DeviceIdentity
    /// The person's mail app, the scene's to fill.
    let mailer: any DiagnosticsMailer
    /// Where a diagnostics bundle is written before it is attached.
    let diagnosticsFolder: URL
    /// The device's battery and conditions, as the support file tells them.
    let deviceBattery: any DeviceBattery
    let deviceConditions: any DeviceConditions
    /// The support report being prepared, previewed or handed to the mail app.
    let reportSource = StateSource<ReportPreparation>(initial: .idle)
    /// The port this device hosts a wired pad through, as the scene read it.
    let devicePort: DevicePort
    let setupSource = StateSource<SetupState?>(initial: nil)
    let supportSource = StateSource<SupportFacts>(initial: .initial)
    /// The on-screen controller's slot: its touches, its resend loop, its motion.
    package let onScreen: OnScreenPad
    let onScreenBattery: DeviceBatteryCadence
    /// The play screen on display; nil while none is.
    let playSource = StateSource<PlayScreen?>(initial: nil)
    /// The slot the phone's touchpad or mouse screen serves: the on-screen
    /// controller, or a pad the phone was aimed at before the screen opened.
    var playTarget = onScreenSlotId
    /// The low-power countdown while a session streams.
    package let lowPower: LowPowerWatch
    /// Whether the shell could raise the dim now: the tabs are on screen,
    /// with no cover or sheet over them.
    let dimAllowed = StateSource<Bool>(initial: false)
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
    /// Why the last attempt the person made on each PC failed, by its id,
    /// kept until the next attempt or until the PC is up.
    let attemptNotices = StateSource<[String: ConnectionFailure]>(initial: [:])
    /// The PCs the person is reaching for right now, by id, pruned as their
    /// links settle; a silent retry is never one of them.
    let reaching = StateSource<Set<String>>(initial: [])
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
        pasteboard: any Pasteboard = InertPasteboard(),
        devicePort: DevicePort = .usbC,
        lowPowerTicker: any Ticker = TimerTicker(),
        deviceBattery: any DeviceBattery = InertDeviceBattery(),
        batteryTicker: any Ticker = TimerTicker(),
        controllerDb: ControllerDbStore,
        identity: DeviceIdentity = .unknown,
        mailer: any DiagnosticsMailer = InertDiagnosticsMailer(),
        diagnosticsFolder: URL = defaultDiagnosticsFolder(),
        deviceConditions: any DeviceConditions = InertDeviceConditions(),
        benchTicker: any Ticker = TimerTicker(),
        benchClock: any BenchClock = SystemBenchClock(),
        phoneHaptics: Bool = phoneHasHaptics()
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
        self.devicePort = devicePort
        self.controllerDb = controllerDb
        self.identity = identity
        self.mailer = mailer
        self.diagnosticsFolder = diagnosticsFolder
        self.deviceBattery = deviceBattery
        self.deviceConditions = deviceConditions
        self.phoneHaptics = phoneHaptics
        bench = BenchStore(feedback: pads.source.feedback, processor: pads.source.processor, ticker: benchTicker, clock: benchClock)
        lowPower = LowPowerWatch(ticker: lowPowerTicker)
        let log = DiagnosticsLogStore()
        diagnosticsLog = log
        recorder = DiagnosticsRecorder(store: log)
        returnPaths = ReturnPathRouter(feedback: pads.source.feedback)
        moonlightFeedback = MoonlightFeedbackRouter(feedback: pads.source.feedback)
        onScreen = OnScreenPad(feed: pads.source.processor.feed(for: onScreenSlotId), ticker: resendTicker, sensor: motionSensor)
        onScreenBattery = DeviceBatteryCadence(ticker: batteryTicker, device: deviceBattery, processor: pads.source.processor)
        applyStoredDeadzones()
        pads.source.processor.setDeadzones(deviceId: onScreenSlotId, GamepadInputProcessor.Deadzones())
        wireNetwork()
        followReaching()
        wireDiagnostics()
        wireMoonlight()
        observeBindingMemory()
        restoreStandingBindings()
        observeLowPower()
        resumeSteamControllers()
        onScreenBattery.start(onScreenSlotId)
        controllerDb.resume()
    }

    /// Every store over the same defaults, the wall clock, the pads iOS
    /// sees and the Steam Controllers over Bluetooth (each weighed against
    /// the device's battery the scene hands in; the Bluetooth radio made only
    /// once the person opts in), the satellite pool with its keys in the
    /// Keychain, the Bonjour scan as the Local Network seam, the App Store,
    /// the phone's sensors, and the controller database over the gateway
    /// and the cache the scene hands in; with none, it never leaves the
    /// device and caches in a folder of its own.
    package convenience init(
        defaults: UserDefaults,
        clock: ClockSource = ClockSource(ticker: TimerTicker(), now: Date.init),
        localNetwork: (any LocalNetworkAccess)? = nil,
        keyStore: any KeyStore = KeychainKeyStore(),
        pins: CertPins = CertPins(file: CertPins.defaultFile()),
        tips: any TipStore = StoreKitTipStore(),
        controllerSource: (any ControllerSource)? = nil,
        motionSensor: any MotionSensor = DeviceMotionSensor(),
        resendTicker: any Ticker = TimerTicker(),
        diagnostics: DiagnosticsSource = DiagnosticsSource(ticker: TimerTicker()),
        pasteboard: any Pasteboard = InertPasteboard(),
        deviceBattery: any DeviceBattery = InertDeviceBattery(),
        batteryTicker: any Ticker = TimerTicker(),
        deviceKind: DeviceKind = .phone,
        devicePort: DevicePort = .usbC,
        lowPowerTicker: any Ticker = TimerTicker(),
        steamRadio: @escaping SteamRadioFactory = { CoreBluetoothRadio(events: $0, queue: $1) },
        steamClock: (any SteamClock)? = nil,
        controllerDbGateway: any ControllerDbGateway = OfflineControllerDbGateway(),
        controllerDbCache: ControllerDbCache? = nil,
        controllerDbTicker: any Ticker = TimerTicker(),
        identity: DeviceIdentity = .unknown,
        mailer: any DiagnosticsMailer = InertDiagnosticsMailer(),
        deviceConditions: any DeviceConditions = InertDeviceConditions(),
        benchTicker: any Ticker = TimerTicker(),
        benchClock: any BenchClock = SystemBenchClock(),
        phoneHaptics: Bool = phoneHasHaptics()
    ) {
        let device = DevicePreferenceStore(defaults: defaults)
        let network = NetworkStack(defaults: defaults, keyStore: keyStore, pins: pins) { wireDeviceName(device.state, on: deviceKind) }
        let source = controllerSource ?? GameControllerInput(deviceBattery: deviceBattery)
        let steam = SteamBluetoothPads(
            processor: source.processor,
            feedback: source.feedback,
            makeRadio: steamRadio,
            clock: steamClock,
            deviceBattery: deviceBattery
        )
        let controllerDb = ControllerDbStore(
            bundled: BundledControllerDb.load() ?? .empty,
            cache: controllerDbCache ?? ControllerDbCache(directory: privateControllerDbFolder()),
            gateway: controllerDbGateway,
            preferences: ControllerDbPreferenceStore(defaults: defaults),
            ticker: controllerDbTicker
        )
        self.init(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: device,
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: clock,
            localNetwork: localNetwork ?? BonjourLocalNetworkAccess(wifi: network.wifi),
            pads: ControllerStack(source: source, defaults: defaults, steam: steam),
            network: network,
            tips: tips,
            motionSensor: motionSensor,
            resendTicker: resendTicker,
            diagnostics: diagnostics,
            pasteboard: pasteboard,
            devicePort: devicePort,
            lowPowerTicker: lowPowerTicker,
            deviceBattery: deviceBattery,
            batteryTicker: batteryTicker,
            controllerDb: controllerDb,
            identity: identity,
            mailer: mailer,
            deviceConditions: deviceConditions,
            benchTicker: benchTicker,
            benchClock: benchClock,
            phoneHaptics: phoneHaptics
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
}

/// The temporary folder a diagnostics bundle is written to before the mail
/// app takes it; iOS empties it on its own.
package func defaultDiagnosticsFolder() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("Diagnostics", isDirectory: true)
}

/// A cache folder of a model's own, for a model the scene did not build,
/// which never downloads into it.
func privateControllerDbFolder() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("controllers-\(UUID().uuidString)", isDirectory: true)
}
