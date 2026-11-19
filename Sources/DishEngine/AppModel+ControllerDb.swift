// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The controller database: Settings' switch and Check now, the facts
/// Settings and Diagnostics show, each pad's record, and Diagnostics' Email
/// diagnostics, which writes the bundle and hands it to the mail seam.
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

    /// Diagnostics › Email diagnostics: the bundle written to a file of its
    /// own, then a message to support with `body`, the summary the page
    /// worded, for the person to send from their own mail app.
    func emailDiagnostics(body: String) {
        diagnostics.refresh()
        let facts = diagnosticsBundleFacts(createdAtMs: wallClockMilliseconds())
        guard let file = writeDiagnosticsBundle(facts) else { return }
        let subject = diagnosticsMailSubject(app: DiagnosticsApp.mailName, version: identity.appVersion, model: identity.model)
        mailer.compose(DiagnosticsMail(recipient: DiagnosticsMailAddress.support, subject: subject, body: body, attachment: file))
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

    func diagnosticsBundleFacts(createdAtMs: Int64) -> DiagnosticsBundleFacts {
        DiagnosticsBundleFacts(
            createdAtMs: createdAtMs,
            identity: identity,
            controllerDb: controllerDb.status,
            controllers: controllerFacts,
            hosts: diagnostics.state.hosts,
            events: diagnosticsLog.state
        )
    }

    /// `dish-diagnostics-dish-ios-<yyyyMMdd-HHmmss>.json` in the folder the
    /// model was handed, which iOS empties on its own; nil when it cannot be
    /// written.
    private func writeDiagnosticsBundle(_ facts: DiagnosticsBundleFacts) -> URL? {
        let name = diagnosticsFileName(app: DiagnosticsApp.name, atMs: facts.createdAtMs, timeZone: .current)
        let file = diagnosticsFolder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: diagnosticsFolder, withIntermediateDirectories: true)
            try encodeDiagnosticsBundle(diagnosticsBundle(facts)).write(to: file, options: .atomic)
            return file
        } catch {
            return nil
        }
    }
}
