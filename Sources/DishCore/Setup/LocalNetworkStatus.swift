// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Where iOS stands on Dish looking for devices on the Wi‑Fi: not asked yet,
/// allowed, or turned off for Dish in Settings.
public enum LocalNetworkStatus: Equatable, Sendable {
    case unknown
    case allowed
    case denied
}
