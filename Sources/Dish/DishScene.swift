// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI
import UIKit

/// The one scene. The composition root's objects are made here once and
/// handed to the shell as environment values. It is not a view: the clock,
/// the defaults and UIKit's shared objects are allowed here and nowhere
/// under `UI/`, and it is the one place the window is turned.
@MainActor
public struct DishScene: Scene {

    @State private var model: AppModel
    @State private var navigation: NavigationStore
    /// THIRD_PARTY.md from the package's resource bundle, for the licenses page.
    private let notice = thirdPartyNotice(in: L10n.app.catalog.bundle)
    private let orientation: OrientationLock
    @Environment(\.scenePhase) private var scenePhase

    /// `orientation` is the app delegate the `@main` app declared.
    public init(orientation: OrientationLock) {
        self.orientation = orientation
        let model = AppModel(defaults: .standard, pasteboard: SystemPasteboard())
        _model = State(initialValue: model)
        let navigation = NavigationStore(
            onboarding: model.onboarding,
            startSetup: { model.startSetup(setupStart($0)) },
            endSetup: model.endSetup,
            startPlay: model.openPlay,
            endPlay: model.closePlay,
            beginPairing: { model.beginPairing(serverId: $0) },
            cancelPairing: model.cancelPairing
        )
        _navigation = State(initialValue: navigation)
    }

    public var body: some Scene {
        WindowGroup {
            ShellView()
                .environment(model)
                .environment(navigation)
                .environment(\.settingsURL, URL(string: UIApplication.openSettingsURLString))
                .environment(\.appVersion, shortVersion(of: .main))
                .environment(\.thirdPartyNotice, notice)
                .preferredColorScheme(colorScheme(for: model.shellFacts.preferences.appearance))
                .onChange(of: idleTimerDisabled(facts: model.shellFacts), initial: true) { holdScreenOn($1) }
                .onChange(of: screenOrientation(for: navigation.state.cover), initial: true) { turn(to: $1) }
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
        let mask = interfaceMask(screenOrientation)
        orientation.mask = mask
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask))
            scene.windows.compactMap(\.rootViewController).forEach(refreshOrientations)
        }
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
