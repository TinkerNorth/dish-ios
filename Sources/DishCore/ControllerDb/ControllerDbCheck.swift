// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The check against the website (sections 6.3 and 6.4) as decisions: whether
// a check may ask at all, what the manifest's answer means, what the
// downloaded files make of the cache, and when the next check is due. The
// engine performs the requests these name and nothing else; with the switch
// off it performs none.

import Foundation

/// The last check's result, in the bundle's and Diagnostics' words.
package enum ControllerDbCheckResult: String, CaseIterable, Equatable {
    case upToDate
    case updated
    case offline
    case invalid
    case off
}

package enum ControllerDbSchedule {
    /// Ten seconds after launch.
    package static let firstCheckDelayMs: Int64 = 10000
    /// Then every six hours while the app is in the foreground.
    package static let intervalMs: Int64 = 6 * 60 * 60 * 1000
    package static let baseURLString = "https://dish.tinkernorth.com/controllers/v1/"
}

/// Whether a check may send anything.
package enum ControllerDbGate: Equatable {
    case ask
    /// The switch is off: nothing leaves the device, and the check reads so.
    case stay(ControllerDbCheckResult)
}

package func controllerDbGate(checksEnabled: Bool) -> ControllerDbGate {
    checksEnabled ? .ask : .stay(.off)
}

/// The manifest request's answer.
package enum ManifestReply: Equatable {
    /// 304 to our `If-None-Match`.
    case notModified
    case body(Data, etag: String?)
    /// No answer, or a status that carries no manifest.
    case unreachable
}

/// 304 is "nothing new", 200 a manifest, anything else no answer.
package func manifestReply(status: Int, body: Data, etag: String?) -> ManifestReply {
    switch status {
    case 304: .notModified
    case 200: .body(body, etag: etag)
    default: .unreachable
    }
}

package enum ManifestStep: Equatable {
    case done(ControllerDbCheckResult)
    /// A newer version: fetch every file it names.
    case download(ControllerDbManifest)
}

/// 304 and a version no newer than the one in force are done; a body that
/// is not a schema 1 manifest is invalid.
package func manifestStep(_ reply: ManifestReply, activeVersion: Int) -> ManifestStep {
    switch reply {
    case .notModified: .done(.upToDate)
    case .unreachable: .done(.offline)
    case let .body(data, _): manifestBodyStep(data, activeVersion: activeVersion)
    }
}

private func manifestBodyStep(_ data: Data, activeVersion: Int) -> ManifestStep {
    guard case let .success(manifest) = decodeControllerDbManifest(data) else { return .done(.invalid) }
    guard manifest.dbVersion > activeVersion else { return .done(.upToDate) }
    return .download(manifest)
}

package enum InstallStep: Equatable {
    case done(ControllerDbCheckResult)
    /// Swap the cache to this set's files, whole.
    case install(ControllerDbSet)
}

/// Files that did not all arrive are offline; files that arrived and do not
/// verify or parse are invalid; the previous cache stays either way.
package func installStep(manifest: ControllerDbManifest, files: [String: Data]?) -> InstallStep {
    guard let files else { return .done(.offline) }
    guard let set = verifiedControllerDbSet(manifest: manifest, files: files) else { return .done(.invalid) }
    return .install(set)
}

/// How long until the next check: ten seconds when none ran this run, else
/// six hours after the last, and never sooner than ten seconds, so an app
/// that comes back to the foreground overdue settles before it asks.
package func controllerDbCheckDelayMs(lastCheckThisRunMs: Int64?, nowMs: Int64) -> Int64 {
    guard let last = lastCheckThisRunMs else { return ControllerDbSchedule.firstCheckDelayMs }
    let due = last + ControllerDbSchedule.intervalMs - nowMs
    return max(ControllerDbSchedule.firstCheckDelayMs, due)
}

/// What Settings and Diagnostics show of the data.
package struct ControllerDbStatus: Equatable {
    package let bundledVersion: Int
    package let activeVersion: Int
    package let source: ControllerDbSource
    package let checksEnabled: Bool
    /// Milliseconds since the Unix epoch; nil before the first check.
    package let lastCheckAtMs: Int64?
    package let lastCheckResult: ControllerDbCheckResult?
    /// A check is under way.
    package let checking: Bool

    package init(
        bundledVersion: Int,
        activeVersion: Int,
        source: ControllerDbSource,
        checksEnabled: Bool,
        lastCheckAtMs: Int64? = nil,
        lastCheckResult: ControllerDbCheckResult? = nil,
        checking: Bool = false
    ) {
        self.bundledVersion = bundledVersion
        self.activeVersion = activeVersion
        self.source = source
        self.checksEnabled = checksEnabled
        self.lastCheckAtMs = lastCheckAtMs
        self.lastCheckResult = lastCheckResult
        self.checking = checking
    }
}
