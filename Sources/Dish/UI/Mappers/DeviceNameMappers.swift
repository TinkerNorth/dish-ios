// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import Foundation

/// Settings › Name on your PC.
struct DeviceNamePageState: Equatable {
    let title: String
    /// What iOS calls every iPhone, shown while the field is empty.
    let placeholder: String
    /// The field's starting text: the stored name, empty while there is none.
    let draft: String
    let footer: String
}

func deviceNamePageState(preferences: PreferencesFacts, words: L10n = .app) -> DeviceNamePageState {
    DeviceNamePageState(
        title: pageTitle(.deviceName, words: words),
        placeholder: words.iPhone,
        draft: preferences.deviceName,
        footer: words.deviceNamePageFooter
    )
}
