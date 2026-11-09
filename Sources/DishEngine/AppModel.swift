// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation
import Observation

/// The composition root: it holds every store and seam and vends the facts
/// the shell draws. Intents live in extensions by topic and are the only
/// thing a view calls. The controllers come from the GameController bridge;
/// connections and the session have no source yet, so their facts are real
/// and empty.
@MainActor
@Observable
package final class AppModel {
    package let onboarding: OnboardingPreferenceStore
    let appearance: AppearancePreferenceStore
    let device: DevicePreferenceStore
    let streaming: StreamingPreferenceStore
    let clock: ClockSource
    package let localNetwork: any LocalNetworkAccess
    package let bindings: BindingRequests
    /// The pads iOS sees and their stores.
    package let pads: ControllerStack
    /// The App Store, for Support Dish.
    let tips: any TipStore
    let setupSource = StateSource<SetupState?>(initial: nil)
    let supportSource = StateSource<SupportFacts>(initial: .initial)
    /// The on-screen controller's slot: its touches, its resend loop, its motion.
    package let onScreen: OnScreenPad
    /// The play screen on display; nil while none is.
    let playSource = StateSource<PlayScreen?>(initial: nil)
    /// Whether the on-screen controller is one of the controllers.
    let onScreenListed = StateSource<Bool>(initial: false)

    package init(
        onboarding: OnboardingPreferenceStore,
        appearance: AppearancePreferenceStore,
        device: DevicePreferenceStore,
        streaming: StreamingPreferenceStore,
        clock: ClockSource,
        localNetwork: any LocalNetworkAccess,
        bindings: BindingRequests,
        pads: ControllerStack,
        tips: any TipStore,
        motionSensor: any MotionSensor,
        resendTicker: any Ticker
    ) {
        self.onboarding = onboarding
        self.appearance = appearance
        self.device = device
        self.streaming = streaming
        self.clock = clock
        self.localNetwork = localNetwork
        self.bindings = bindings
        self.pads = pads
        self.tips = tips
        onScreen = OnScreenPad(feed: pads.source.processor.feed(for: onScreenSlotId), ticker: resendTicker, sensor: motionSensor)
        applyStoredDeadzones()
        pads.source.processor.setDeadzones(deviceId: onScreenSlotId, GamepadInputProcessor.Deadzones())
    }

    /// Every store over the same defaults, the wall clock, the pads iOS
    /// sees, the App Store, and the seams the discovery and binding waves
    /// fill in.
    package convenience init(
        defaults: UserDefaults,
        clock: ClockSource = ClockSource(ticker: TimerTicker(), now: Date.init),
        localNetwork: any LocalNetworkAccess = RecordedLocalNetworkAccess(),
        bindings: BindingRequests = BindingRequests(),
        tips: any TipStore = StoreKitTipStore(),
        controllerSource: any ControllerSource = GameControllerInput(),
        motionSensor: any MotionSensor = DeviceMotionSensor(),
        resendTicker: any Ticker = TimerTicker()
    ) {
        self.init(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: clock,
            localNetwork: localNetwork,
            bindings: bindings,
            pads: ControllerStack(source: controllerSource, defaults: defaults),
            tips: tips,
            motionSensor: motionSensor,
            resendTicker: resendTicker
        )
    }

    /// The setup walk on screen; nil while the cover is down.
    package var setup: SetupState? {
        setupSource.state
    }

    package var shellFacts: ShellFacts {
        ShellFacts(
            controllers: controllerFacts,
            attachedPads: attachedPadFacts,
            paired: [],
            found: [],
            scanning: false,
            session: nil,
            localNetwork: localNetwork.status,
            preferences: preferencesFacts,
            now: clock.state,
            setup: setup,
            support: supportSource.state,
            play: playFacts
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
