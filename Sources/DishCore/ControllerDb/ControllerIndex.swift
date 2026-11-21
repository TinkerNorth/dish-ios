// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The immutable index from `vid:pid` to record (section 6.2): the bundled
// set, or the cached download when its version is greater. A newer version
// replaces the whole set; records are never merged one by one. And which of
// a record's issues a pad shows on this device (section 4.1).

import Foundation

/// Where the set in force came from.
package enum ControllerDbSource: String, Equatable {
    case bundled
    case cache
}

package struct ControllerIndex: Equatable {
    package let dbVersion: Int
    package let source: ControllerDbSource
    package let strings: ControllerStrings
    private let byUsb: [String: ControllerRecord]
    private let byBluetooth: [String: ControllerRecord]

    /// The first record to name an id keeps it, as the lookups the tables
    /// were generated from return the first match.
    package init(_ set: ControllerDbSet, source: ControllerDbSource) {
        dbVersion = set.dbVersion
        self.source = source
        strings = set.strings
        byUsb = firstRecordById(set.database.records, ids: \.usb)
        byBluetooth = firstRecordById(set.database.records, ids: \.bluetooth)
    }

    package func record(usb identity: String) -> ControllerRecord? {
        byUsb[identity.lowercased()]
    }

    package func record(bluetooth identity: String) -> ControllerRecord? {
        byBluetooth[identity.lowercased()]
    }
}

private func firstRecordById(_ records: [ControllerRecord], ids: KeyPath<ControllerRecord, [String]>) -> [String: ControllerRecord] {
    var index: [String: ControllerRecord] = [:]
    for record in records {
        for id in record[keyPath: ids] where index[id] == nil {
            index[id] = record
        }
    }
    return index
}

/// The cached download only when it is newer than what the app was built with.
package func activeControllerIndex(bundled: ControllerDbSet, cached: ControllerDbSet?) -> ControllerIndex {
    guard let cached, cached.dbVersion > bundled.dbVersion else { return ControllerIndex(bundled, source: .bundled) }
    return ControllerIndex(cached, source: .cache)
}

/// The device a pad is attached to, as an issue names one: its model, the
/// platform's name under an issue's `os`, and that platform's major version.
package struct ControllerHost: Equatable {
    package let model: String
    package let platform: String
    /// Nil when the version is not known, which matches no issue tied to one.
    package let osMajor: Int?

    package init(model: String, platform: String, osMajor: Int?) {
        self.model = model
        self.platform = platform
        self.osMajor = osMajor
    }
}

/// The issues a pad on `transport` shows on `host`: each that is open and
/// whose transport, device and system are the pad's and the host's, or absent.
package func issuesShown(_ issues: [ControllerIssue], transport: ControllerTransport, host: ControllerHost) -> [ControllerIssue] {
    issues.filter { issue in
        let onThisTransport = issue.transport.map { $0 == transport } ?? true
        let onThisDevice = issue.device.map { $0 == host.model } ?? true
        let onThisSystem = issue.os.isEmpty || (host.osMajor.map { issue.os[host.platform] == $0 } ?? false)
        return issue.open && onThisTransport && onThisDevice && onThisSystem
    }
}
