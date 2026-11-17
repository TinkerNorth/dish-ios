// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation
import SwiftUI

/// THIS IPHONE.
struct DeviceSectionState: Equatable {
    let title: String
    let nameTitle: String
    /// The stored name, or "iPhone" while there is none.
    let name: String
    let footer: String
}

/// One Dim screen after choice.
struct DimOptionState: Equatable, Identifiable {
    let delay: DimDelay
    let title: String

    var id: DimDelay {
        delay
    }
}

/// WHILE STREAMING.
struct StreamingSectionState: Equatable {
    let title: String
    let keepScreenOnTitle: String
    let keepScreenOn: Bool
    let dimTitle: String
    let dimAfter: DimDelay
    let options: [DimOptionState]
    let footer: String
}

/// The three global switches that are a toggle each.
enum ForwardedFeature: Equatable {
    case motion, rumble, touchpad
}

/// One toggle of FORWARDED FEATURES.
struct ForwardedFeatureRowState: Equatable, Identifiable {
    let feature: ForwardedFeature
    let title: String
    let detail: String
    let isOn: Bool

    var id: ForwardedFeature {
        feature
    }
}

/// One light bar choice.
struct LightBarOptionState: Equatable, Identifiable {
    let mode: LightbarMode
    let title: String

    var id: LightbarMode {
        mode
    }
}

/// FORWARDED FEATURES: the global switches above every controller's own.
struct ForwardedFeaturesSectionState: Equatable {
    let title: String
    let rows: [ForwardedFeatureRowState]
    let lightBarTitle: String
    let lightBar: LightbarMode
    let lightBarOptions: [LightBarOptionState]
    let lightBarDetail: String
    let footer: String
}

/// The line under Read over Bluetooth: where the Steam Controllers stand,
/// in the warning colour when the person has something to change.
struct SteamBluetoothLine: Equatable {
    let text: String
    let warns: Bool

    var color: Color {
        warns ? DishTheme.warning : DishTheme.muted
    }
}

/// STEAM CONTROLLERS: the opt-in, where it stands, and why it exists.
struct SteamControllersSectionState: Equatable {
    let title: String
    let toggleTitle: String
    let isOn: Bool
    let line: SteamBluetoothLine
    let footer: String
}

/// SETUP & HELP: Setup guide, Help & FAQ and Diagnostics.
struct SetupHelpSectionState: Equatable {
    let title: String
    let guide: String
    let guideSymbol: String
    let help: String
    let helpSymbol: String
    let diagnostics: String
    let diagnosticsSymbol: String
}

/// One Appearance choice.
struct AppearanceOptionState: Equatable, Identifiable {
    let appearance: Appearance
    let title: String

    var id: Appearance {
        appearance
    }
}

/// APPEARANCE.
struct AppearanceSectionState: Equatable {
    let title: String
    let selected: Appearance
    let options: [AppearanceOptionState]
}

/// ABOUT, as D5 draws it with Support Dish at its head: the tips, the
/// version, the links and the licenses.
struct AboutSectionState: Equatable {
    let title: String
    let support: String
    /// The row's value: what Support Dish offers.
    let supportValue: String
    let supportSymbol: String
    let versionTitle: String
    let version: String
    let links: [PageLink]
    let licenses: String
}

/// The Settings tab (D5), section by section.
struct SettingsPageState: Equatable {
    let title: String
    let device: DeviceSectionState
    let streaming: StreamingSectionState
    let features: ForwardedFeaturesSectionState
    let steamControllers: SteamControllersSectionState
    let help: SetupHelpSectionState
    let appearance: AppearanceSectionState
    let about: AboutSectionState
}

func settingsPageState(
    preferences: PreferencesFacts,
    forwarding: ForwardingFlags = ForwardingFlags(),
    steamBluetooth: SteamBluetoothStatus = .off,
    appVersion: String,
    words: L10n = .app
) -> SettingsPageState {
    SettingsPageState(
        title: words.settings,
        device: DeviceSectionState(
            title: words.thisIPhone,
            nameTitle: words.nameOnYourPC,
            name: deviceNameText(preferences.deviceName, words: words),
            footer: words.deviceNameFooter
        ),
        streaming: streamingSection(preferences, words: words),
        features: forwardedFeatures(forwarding, words: words),
        steamControllers: steamControllersSection(steamBluetooth, words: words),
        help: SetupHelpSectionState(
            title: words.setupAndHelp,
            guide: words.setupGuide,
            guideSymbol: "sparkles",
            help: words.helpAndFaq,
            helpSymbol: "questionmark.circle",
            diagnostics: words.diagnostics,
            diagnosticsSymbol: DishSymbol.diagnostics
        ),
        appearance: AppearanceSectionState(
            title: words.appearance,
            selected: preferences.appearance,
            options: Appearance.allCases.map { AppearanceOptionState(appearance: $0, title: appearanceText($0, words: words)) }
        ),
        about: aboutSection(appVersion: appVersion, words: words)
    )
}

private func aboutSection(appVersion: String, words: L10n) -> AboutSectionState {
    AboutSectionState(
        title: words.about,
        support: words.supportDish,
        supportValue: words.tips,
        supportSymbol: heartSymbol,
        versionTitle: words.version,
        version: appVersion,
        links: [
            PageLink(title: words.website, url: DishLinks.website),
            PageLink(title: words.sourceCode, url: DishLinks.source),
            PageLink(title: words.privacyPolicy, url: DishLinks.privacy)
        ],
        licenses: words.openSourceLicenses
    )
}

private func forwardedFeatures(_ flags: ForwardingFlags, words: L10n) -> ForwardedFeaturesSectionState {
    ForwardedFeaturesSectionState(
        title: words.forwardedFeatures,
        rows: [
            ForwardedFeatureRowState(feature: .motion, title: words.setupMotion, detail: words.motionDetail, isOn: flags.motion),
            ForwardedFeatureRowState(feature: .rumble, title: words.carriesRumble, detail: words.rumbleDetail, isOn: flags.rumble),
            ForwardedFeatureRowState(feature: .touchpad, title: words.carriesTouchpad, detail: words.touchpadDetail, isOn: flags.touchpad)
        ],
        lightBarTitle: words.lightBar,
        lightBar: flags.lightbar ? .followGame : .off,
        lightBarOptions: LightbarMode.allCases.map { LightBarOptionState(mode: $0, title: lightbarModeText($0, words: words)) },
        lightBarDetail: words.lightbarDetail,
        footer: words.featuresFootnote
    )
}

private func steamControllersSection(_ status: SteamBluetoothStatus, words: L10n) -> SteamControllersSectionState {
    SteamControllersSectionState(
        title: words.steamControllers,
        toggleTitle: words.readOverBluetooth,
        isOn: status != .off,
        line: steamBluetoothLine(status, words: words),
        footer: words.steamControllersFooter
    )
}

/// Each state its own line; the ones the person can act on warn.
func steamBluetoothLine(_ status: SteamBluetoothStatus, words: L10n = .app) -> SteamBluetoothLine {
    switch status {
    case .off: SteamBluetoothLine(text: words.steamBluetoothUnused, warns: false)
    case .waiting: SteamBluetoothLine(text: words.steamBluetoothWaiting, warns: false)
    case .on: SteamBluetoothLine(text: words.steamBluetoothReading, warns: false)
    case .bluetoothOff: SteamBluetoothLine(text: words.steamBluetoothPoweredOff, warns: true)
    case .refused: SteamBluetoothLine(text: words.steamBluetoothRefused, warns: true)
    case .restricted: SteamBluetoothLine(text: words.steamBluetoothRestricted, warns: true)
    case .unsupported: SteamBluetoothLine(text: words.steamBluetoothUnsupported, warns: true)
    }
}

/// The light bar picker's option words.
func lightbarModeText(_ mode: LightbarMode, words: L10n = .app) -> String {
    switch mode {
    case .followGame: words.followGame
    case .off: words.off
    }
}

private func streamingSection(_ preferences: PreferencesFacts, words: L10n) -> StreamingSectionState {
    StreamingSectionState(
        title: words.whileStreaming,
        keepScreenOnTitle: words.keepScreenOn,
        keepScreenOn: preferences.keepScreenOn,
        dimTitle: words.dimScreenAfter,
        dimAfter: preferences.dimAfter,
        options: DimDelay.allCases.map { DimOptionState(delay: $0, title: dimDelayText($0, words: words)) },
        footer: words.whileStreamingFooter
    )
}

/// The name Satellite sees: the stored one, or what iOS calls every iPhone.
func deviceNameText(_ stored: String, words: L10n = .app) -> String {
    stored.isEmpty ? words.iPhone : stored
}

private let secondsPerMinute = 60

func dimDelayText(_ delay: DimDelay, words: L10n = .app) -> String {
    switch delay {
    case .tenSeconds, .twentySeconds, .thirtySeconds: words.seconds(delay.rawValue)
    case .oneMinute, .twoMinutes: words.minutes(delay.rawValue / secondsPerMinute)
    case .never: words.never
    }
}

func appearanceText(_ appearance: Appearance, words: L10n = .app) -> String {
    switch appearance {
    case .system: words.system
    case .light: words.light
    case .dark: words.dark
    }
}
