// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import AppIntents
import DishEngine
import SwiftUI
import UIKit

/// The one scene. The composition root's objects are made here once and
/// handed to the shell as environment values, and to App Intents as the
/// router its intents post through. It is not a view: the clock, the
/// defaults and the host's shared objects are allowed here and nowhere
/// under `UI/`, it is the one place the window is turned, and with its
/// `WindowReader` the one place the device and the window are read.
@MainActor
public struct DishScene: Scene {

    /// The model, the navigation store and the router App Intents post
    /// through, made the first time the kept build reads them.
    @State private var root: OnFirstUse<SceneRoot>
    /// THIRD_PARTY.md from the package's resource bundle, for the licenses page.
    private let notice = thirdPartyNotice(in: L10n.app.catalog.bundle)
    private let orientation: OrientationLock
    /// The device, read once: an iPhone turns for play alone, an iPad with
    /// the device.
    private let idiom: DeviceIdiom
    @Environment(\.scenePhase) private var scenePhase

    /// `orientation` is the app delegate the `@main` app declared. Nothing
    /// is made here: SwiftUI calls this again on its own and keeps only the
    /// first build's state, so the root is made on first use.
    public init(orientation: OrientationLock) {
        self.orientation = orientation
        let idiom = deviceIdiom(UIDevice.current.userInterfaceIdiom)
        self.idiom = idiom
        _root = State(initialValue: OnFirstUse { SceneRoot(orientation: orientation, idiom: idiom) })
    }

    private var model: AppModel {
        root.value.model
    }

    private var navigation: NavigationStore {
        root.value.navigation
    }

    private var router: IntentRouter {
        root.value.router
    }

    public var body: some Scene {
        windowHandingIntentsTheRouter()
    }

    /// The window, once App Intents has the router. The body reads the root
    /// the kept build made, so the one router is handed over here, once,
    /// before any intent reaches the app.
    private func windowHandingIntentsTheRouter() -> some Scene {
        router.register { AppDependencyManager.shared.add(dependency: $0) }
        return WindowGroup {
            ShellView()
                .environment(model)
                .environment(navigation)
                .environment(\.settingsURL, URL(string: UIApplication.openSettingsURLString))
                .environment(\.appVersion, shortVersion(of: .main))
                .environment(\.thirdPartyNotice, notice)
                .modifier(WindowReader())
                .preferredColorScheme(colorScheme(for: model.shellFacts.preferences.appearance))
                .onChange(of: idleTimerDisabled(facts: model.shellFacts), initial: true) { holdScreenOn($1) }
                .onChange(of: screenOrientation(for: navigation.state.cover, idiom: idiom), initial: true) { turn(to: $1) }
                .onChange(of: scenePhase) { scenePhaseChanged($1) }
        }
    }

    /// iOS suspends Dish in the background, so its sessions close the
    /// graceful way there and are reached for again on the way back.
    private func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background: model.enteredBackground()
        case .active: model.enteredForeground()
        case .inactive: break
        @unknown default: break
        }
    }

    /// iOS locks the screen and suspends Dish unless the idle timer is off.
    private func holdScreenOn(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    /// The delegate answers with the new mask from now on, and every window
    /// turns to it: UIKit only rereads the mask when asked to.
    private func turn(to screenOrientation: ScreenOrientation) {
        orientation.follow(screenOrientation)
        let mask = interfaceMask(screenOrientation)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask))
            scene.windows.compactMap(\.rootViewController).forEach(refreshOrientations)
        }
    }
}

/// The composition root the scene keeps: the model over the device's
/// stores and sockets, the navigation store over the model's intents, and
/// the router App Intents post through. TipKit is configured and the window
/// turned for the first time as it is made.
@MainActor
private struct SceneRoot {
    let model: AppModel
    let navigation: NavigationStore
    let router: IntentRouter

    init(orientation: OrientationLock, idiom: DeviceIdiom) {
        TipKitTips.configure(hidden: UserDefaults.standard.bool(forKey: TipKitTips.hiddenKey))
        let model = AppModel(defaults: .standard, pasteboard: SystemPasteboard(), deviceKind: deviceKind(idiom))
        let navigation = NavigationStore(
            onboarding: model.onboarding,
            startSetup: { model.startSetup(setupStart($0)) },
            endSetup: model.endSetup,
            startPlay: model.openPlay,
            endPlay: model.closePlay,
            beginPairing: { model.beginPairing(serverId: $0) },
            cancelPairing: model.cancelPairing,
            connect: model.connect,
            learned: TipKitTips.learned
        )
        orientation.follow(screenOrientation(for: navigation.state.cover, idiom: idiom))
        self.model = model
        self.navigation = navigation
        router = IntentRouter(send: { navigation.send($0) }, paired: { model.shellFacts.paired })
    }
}

/// The device the engine names itself for when the person gave it no name.
func deviceKind(_ idiom: DeviceIdiom) -> DeviceKind {
    switch idiom {
    case .phone: .phone
    case .pad: .pad
    }
}

/// A controller and everything it presents reread their orientations.
@MainActor
private func refreshOrientations(_ controller: UIViewController) {
    controller.setNeedsUpdateOfSupportedInterfaceOrientations()
    if let presented = controller.presentedViewController { refreshOrientations(presented) }
}

/// The bundle's marketing version, empty when the bundle carries none.
private func shortVersion(of bundle: Bundle) -> String {
    bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
}

/// The system clipboard behind the model's `Pasteboard` seam: the one
/// place `UIPasteboard` is touched, so Diagnostics' Copy is an intent.
@MainActor
final class SystemPasteboard: Pasteboard {
    func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
