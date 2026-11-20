// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The controller database: Settings' switch and Check now, the facts
/// Settings and Diagnostics show, and each pad's record.
package extension AppModel {

    var controllerDbFacts: ControllerDbFacts {
        ControllerDbFacts(status: controllerDb.status, strings: controllerDb.index.strings)
    }

    /// Settings › Check for controller updates automatically.
    func setControllerDbChecks(_ enabled: Bool) {
        controllerDb.setChecksEnabled(enabled)
    }

    /// Settings › Check now: one check, whatever the schedule.
    func checkControllerDbNow() {
        controllerDb.checkNow()
    }
}

extension AppModel {

    /// The record for a pad Dish reads over Bluetooth, with the issues it
    /// shows on this device; GameController names no ids, so its pads have none.
    func controllerRecordFact(_ source: PadSource?) -> ControllerRecordFact? {
        switch source {
        case let .bluetooth(vendorId, productId):
            bluetoothRecordFact(controllerIdentity(vendorId: vendorId, productId: productId))
        case .gameController, nil:
            nil
        }
    }

    private func bluetoothRecordFact(_ identity: String) -> ControllerRecordFact? {
        guard let record = controllerDb.index.record(bluetooth: identity) else { return nil }
        let issues = issuesShown(record.issues, transport: .bluetooth, host: self.identity.controllerHost)
        return ControllerRecordFact(id: record.id, verification: record.verification, issues: issues)
    }
}
