// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import Foundation

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

/// SETUP & HELP. Help & FAQ and Diagnostics come with their pages.
struct HelpSectionState: Equatable {
    let title: String
    let guide: String
    let guideSymbol: String
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

/// ABOUT.
struct AboutSectionState: Equatable {
    let title: String
    let versionTitle: String
    let version: String
}

/// The Settings tab (D5), section by section.
struct SettingsPageState: Equatable {
    let title: String
    let device: DeviceSectionState
    let streaming: StreamingSectionState
    let help: HelpSectionState
    let appearance: AppearanceSectionState
    let about: AboutSectionState
}

func settingsPageState(preferences: PreferencesFacts, appVersion: String, words: L10n = .app) -> SettingsPageState {
    SettingsPageState(
        title: words.settings,
        device: DeviceSectionState(
            title: words.thisIPhone,
            nameTitle: words.nameOnYourPC,
            name: deviceNameText(preferences.deviceName, words: words),
            footer: words.deviceNameFooter
        ),
        streaming: streamingSection(preferences, words: words),
        help: HelpSectionState(title: words.setupAndHelp, guide: words.setupGuide, guideSymbol: "sparkles"),
        appearance: AppearanceSectionState(
            title: words.appearance,
            selected: preferences.appearance,
            options: Appearance.allCases.map { AppearanceOptionState(appearance: $0, title: appearanceText($0, words: words)) }
        ),
        about: AboutSectionState(title: words.about, versionTitle: words.version, version: appVersion)
    )
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
