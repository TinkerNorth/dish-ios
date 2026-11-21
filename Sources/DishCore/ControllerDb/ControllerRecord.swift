// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// One controller as the fleet's controller database describes it, schema 1
// (dish-website `docs/controller-db.md`, section 4), cut to what this client
// reads: the ids it shows over USB and Bluetooth, the family that parses it,
// its verification and its known issues. iOS has no Direct path, so the
// input, output, expect and audio sections drive nothing here and are not
// decoded; `Tests/PARITY.md` says so.

import Foundation

/// `support.verification.state`.
package enum ControllerVerification: String, CaseIterable, Equatable {
    case verified
    case imported
    case crowd
    case guessed
    case flagged
}

package enum ControllerTransport: String, CaseIterable, Equatable {
    case usb
    case bluetooth
}

/// One known problem; its title and body live in the strings under
/// `issue.<id>`.
package struct ControllerIssue: Equatable {
    package let id: String
    /// The device it was seen on; nil when it is any.
    package let device: String?
    /// A platform's name to its major version; empty when it is any.
    package let os: [String: Int]
    /// Nil when it is on every transport.
    package let transport: ControllerTransport?
    /// `status` is "open"; a fixed or won't-fix issue stays in the data as
    /// history and is never shown.
    package let open: Bool

    package init(id: String, device: String? = nil, os: [String: Int] = [:], transport: ControllerTransport? = nil, open: Bool = true) {
        self.id = id
        self.device = device
        self.os = os
        self.transport = transport
        self.open = open
    }
}

package struct ControllerRecord: Equatable {
    /// Stable forever; the strings are keyed by it.
    package let id: String
    /// Lowercase `vid:pid`, as the pad shows itself over USB.
    package let usb: [String]
    /// The same, over Bluetooth.
    package let bluetooth: [String]
    /// `input.protocol.ref`, as written, so a family this build does not
    /// know still reads.
    package let family: String
    package let verification: ControllerVerification
    package let issues: [ControllerIssue]

    package init(
        id: String,
        usb: [String] = [],
        bluetooth: [String] = [],
        family: String,
        verification: ControllerVerification,
        issues: [ControllerIssue] = []
    ) {
        self.id = id
        self.usb = usb
        self.bluetooth = bluetooth
        self.family = family
        self.verification = verification
        self.issues = issues
    }
}

/// `controllers.json`: one published version of every record.
package struct ControllerDatabase: Equatable {
    package let dbVersion: Int
    package let records: [ControllerRecord]

    package init(dbVersion: Int, records: [ControllerRecord]) {
        self.dbVersion = dbVersion
        self.records = records
    }
}

/// The index's key for a pad: `vid:pid`, four lowercase hex digits each.
package func controllerIdentity(vendorId: UInt16, productId: UInt16) -> String {
    let vendor = String(format: "%04x", vendorId)
    let product = String(format: "%04x", productId)
    return "\(vendor):\(product)"
}
