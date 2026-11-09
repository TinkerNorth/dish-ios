// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

extension EnvironmentValues {
    /// Settings › Dish, the place Open Settings goes. The scene sets it from
    /// UIKit's settings URL; a view never reads UIApplication itself.
    @Entry var settingsURL: URL?
}
