// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishKernel
import Foundation

/// "Check for controller updates automatically", and what the last check
/// left behind: when it ran, how it ended, and the manifest's ETag for the
/// next `If-None-Match`.
package struct ControllerDbPreferences: Equatable {
    package let checksEnabled: Bool
    package let lastCheckAtMs: Int64?
    package let lastCheckResult: ControllerDbCheckResult?
    package let etag: String?

    package init(checksEnabled: Bool, lastCheckAtMs: Int64? = nil, lastCheckResult: ControllerDbCheckResult? = nil, etag: String? = nil) {
        self.checksEnabled = checksEnabled
        self.lastCheckAtMs = lastCheckAtMs
        self.lastCheckResult = lastCheckResult
        self.etag = etag
    }

    func with(checksEnabled: Bool) -> ControllerDbPreferences {
        ControllerDbPreferences(checksEnabled: checksEnabled, lastCheckAtMs: lastCheckAtMs, lastCheckResult: lastCheckResult, etag: etag)
    }

    func with(check result: ControllerDbCheckResult, atMs: Int64) -> ControllerDbPreferences {
        ControllerDbPreferences(checksEnabled: checksEnabled, lastCheckAtMs: atMs, lastCheckResult: result, etag: etag)
    }

    func with(etag: String?) -> ControllerDbPreferences {
        ControllerDbPreferences(checksEnabled: checksEnabled, lastCheckAtMs: lastCheckAtMs, lastCheckResult: lastCheckResult, etag: etag)
    }
}

/// The switch and the last check under dish-mac's keys: on by default in
/// every build, so a newly supported controller does not wait for a release.
@MainActor
package final class ControllerDbPreferenceStore {
    static let checksEnabledKey = "controller_db_check_enabled"
    static let lastCheckKey = "controller_db_last_check_utc_ms"
    static let lastResultKey = "controller_db_last_check_result"
    static let etagKey = "controller_db_manifest_etag"

    private let defaults: UserDefaults
    private let source: StateSource<ControllerDbPreferences>

    package var state: ControllerDbPreferences {
        source.state
    }

    package init(defaults: UserDefaults) {
        self.defaults = defaults
        source = StateSource(initial: ControllerDbPreferences(
            checksEnabled: defaults.object(forKey: Self.checksEnabledKey) as? Bool ?? true,
            lastCheckAtMs: (defaults.object(forKey: Self.lastCheckKey) as? NSNumber)?.int64Value,
            lastCheckResult: defaults.string(forKey: Self.lastResultKey).flatMap(ControllerDbCheckResult.init(rawValue:)),
            etag: defaults.string(forKey: Self.etagKey)
        ))
    }

    package func setChecksEnabled(_ enabled: Bool) {
        guard enabled != state.checksEnabled else { return }
        defaults.set(enabled, forKey: Self.checksEnabledKey)
        source.updateState { $0.with(checksEnabled: enabled) }
    }

    func recordCheck(_ result: ControllerDbCheckResult, atMs: Int64) {
        defaults.set(NSNumber(value: atMs), forKey: Self.lastCheckKey)
        defaults.set(result.rawValue, forKey: Self.lastResultKey)
        source.updateState { $0.with(check: result, atMs: atMs) }
    }

    func setEtag(_ etag: String?) {
        defaults.set(etag, forKey: Self.etagKey)
        source.updateState { $0.with(etag: etag) }
    }
}
