// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// Report a problem and Ask a question: the file is made from the page's
/// facts, every controller path, the device's conditions and each host
/// from both ends, each live satellite asked for its own snapshot within
/// two seconds; then the person's own mail app opens with it, addressed to
/// support. Nothing leaves the device until they press Send there.
package extension AppModel {

    var reportFacts: ReportFacts {
        ReportFacts(
            controllers: controllerFacts,
            localNetwork: localNetwork.status,
            controllerDb: controllerDbFacts,
            preparation: reportSource.state
        )
    }

    /// Report › Preview file: the file the draft would send, for the person
    /// to read.
    @discardableResult
    func previewReport(_ draft: ReportDraft) -> Task<Void, Never> {
        Task {
            // The preview reads the file through the report's state.
            _ = await preparedReport(draft)
        }
    }

    /// Report › Continue in Mail: the file previewed for this draft, or a
    /// fresh one, handed to the mail app with the app's words.
    @discardableResult
    func continueReport(_ draft: ReportDraft, mail: ReportMail) -> Task<Void, Never> {
        Task {
            guard let prepared = await preparedReport(draft) else { return }
            composeReport(prepared, mail: mail)
        }
    }
}

extension AppModel {

    /// The file already made for the same draft, else one made now. A
    /// draft that changed since the preview is a different file.
    private func preparedReport(_ draft: ReportDraft) async -> PreparedReport? {
        if case let .ready(made, prepared) = reportSource.state, made == draft { return prepared }
        reportSource.setState(.preparing(draft))
        let prepared = await prepareReport(draft)
        reportSource.setState(prepared.map { .ready(draft, $0) } ?? .failed(draft))
        return prepared
    }

    private func composeReport(_ prepared: PreparedReport, mail: ReportMail) {
        let subject = supportMailSubject(
            category: mail.category,
            app: DiagnosticsApp.mailName,
            version: identity.appVersion,
            model: identity.model
        )
        let message = DiagnosticsMail(
            recipient: DiagnosticsMailAddress.support,
            subject: subject,
            body: mail.body,
            attachment: prepared.file
        )
        mailer.compose(message)
    }

    /// Every figure read now, the hosts asked together, then the file
    /// written; nil when it cannot be written.
    private func prepareReport(_ draft: ReportDraft) async -> PreparedReport? {
        diagnostics.refresh()
        let hosts = diagnostics.state.hosts
        let replies = await snapshotReplies(hosts.filter(isAsked).map(\.id))
        let facts = DiagnosticsBundleFacts(
            createdAtMs: wallClockMilliseconds(),
            identity: identity,
            controllerDb: controllerDb.status,
            controllers: controllerFacts,
            hosts: hosts,
            events: diagnosticsLog.state,
            report: bundleReport(draft),
            conditions: deviceConditionsReading,
            paths: padPathReadings,
            hostReadings: keyed(hosts.map { ($0.id, hostReading($0, reply: replies[$0.id])) })
        )
        return writeReport(facts)
    }

    /// A satellite is asked unless its capabilities say it is older than
    /// the route; a Moonlight host has none.
    private func isAsked(_ host: HostDiagnostics) -> Bool {
        host.summary.kind != .moonlight && asksForConnectionDiagnostics(network.wifi.capabilitiesFacts(host.id))
    }

    /// Each live satellite's answer, asked at once so the wait is the
    /// slowest host's and never more than the timeout.
    private func snapshotReplies(_ ids: [String]) async -> [String: SnapshotReply] {
        let wifi = network.wifi
        return await withTaskGroup(of: HostAnswer.self) { group in
            for id in ids {
                group.addTask { await askForSnapshot(id, of: wifi) }
            }
            var replies: [String: SnapshotReply] = [:]
            while let answer = await group.next() {
                replies[answer.id] = answer.reply
            }
            return replies
        }
    }

    /// The controller the person picked, by its record or its name; the
    /// on-screen controller has neither and goes by its slot id.
    private func bundleReport(_ draft: ReportDraft) -> BundleReport {
        let picked = controllerFacts.first { $0.id == draft.controllerId }
        let named = picked.map { $0.record?.id ?? ($0.name.isEmpty ? $0.id : $0.name) }
        return BundleReport(category: draft.category, text: draft.text, controller: named)
    }

    private var deviceConditionsReading: BundleConditions {
        BundleConditions(
            battery: bundleBattery(deviceBattery.reading),
            thermal: deviceConditions.thermal,
            powerSave: deviceConditions.lowPowerMode
        )
    }

    /// Each controller's frames, rate, last state and feedback lanes.
    private var padPathReadings: [String: PadPathReading] {
        let rates = keyed(diagnostics.state.pads.map { ($0.id, $0.rates.reportHz) })
        return keyed(controllerFacts.map { ($0.id, padPathReading($0.id, rateHz: rates[$0.id])) })
    }

    /// The rate is the Diagnostics source's last reading; nil for a pad it
    /// never sampled.
    private func padPathReading(_ slotId: String, rateHz: Int?) -> PadPathReading {
        let latest = pads.source.processor.latestInput(slotId)
        return PadPathReading(
            frames: latest?.reports ?? 0,
            rateHz: rateHz,
            last: latest?.filtered,
            output: pads.source.feedback.output(for: slotId) ?? .none
        )
    }

    /// A host from both ends: the client's view of the session, and what
    /// the host said of itself, or the client's own copy and why.
    private func hostReading(_ host: HostDiagnostics, reply: SnapshotReply?) -> HostReading {
        let records = keyed(controllerFacts.compactMap { fact in fact.record.map { (fact.id, $0.id) } })
        guard host.summary.kind != .moonlight else {
            let moonlight = host.moonlight
            return HostReading(
                session: moonlight.flatMap { moonlightSessionBundle($0, records: records) },
                snapshot: moonlightSnapshot(moonlight?.info)
            )
        }
        let cached = network.wifi.capabilitiesFacts(host.id)
        return HostReading(
            version: cached.flatMap { $0.serverVersion.isEmpty ? nil : $0.serverVersion },
            session: network.wifi.get(host.id).flatMap { satelliteSessionBundle(of: $0, records: records, slugs: catalogSlugs(host.id)) },
            snapshot: satelliteSnapshot(reply.map(snapshotOutcome), cached: cached)
        )
    }

    /// The cached catalog's slug for each wire type; empty with no catalog.
    private func catalogSlugs(_ id: String) -> [Int: String] {
        let types = network.wifi.catalogs[id]?.controllerTypes ?? []
        return Dictionary(types.map { ($0.id, $0.slug) }) { first, _ in first }
    }

    /// `dish-diagnostics-dish-ios-<yyyyMMdd-HHmmss>.json` in the folder the
    /// model was handed, which iOS empties on its own, with its text for the
    /// preview; nil when it cannot be written.
    private func writeReport(_ facts: DiagnosticsBundleFacts) -> PreparedReport? {
        let name = diagnosticsFileName(app: DiagnosticsApp.name, atMs: facts.createdAtMs, timeZone: .current)
        let file = diagnosticsFolder.appendingPathComponent(name)
        let data = encodeDiagnosticsBundle(diagnosticsBundle(facts))
        guard let text = String(bytes: data, encoding: .utf8) else { return nil }
        do {
            try FileManager.default.createDirectory(at: diagnosticsFolder, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            return PreparedReport(file: file, text: text)
        } catch {
            return nil
        }
    }
}

/// One satellite's answer to the diagnostics route; nil when it was not asked.
private struct HostAnswer {
    let id: String
    let reply: SnapshotReply?
}

@MainActor
private func askForSnapshot(_ id: String, of wifi: WifiConnectionManager) async -> HostAnswer {
    let reply = await wifi.connectionDiagnostics(id)
    return HostAnswer(id: id, reply: reply)
}

/// Pairs as a table, the first of a repeated key kept.
private func keyed<Value>(_ pairs: [(String, Value)]) -> [String: Value] {
    Dictionary(pairs) { first, _ in first }
}
