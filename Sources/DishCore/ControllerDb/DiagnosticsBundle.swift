// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// `dish-diagnostics.v1` (dish-website `docs/diagnostics-bundle.md`): one JSON
// file, the same envelope from every Dish client, handed to the person's
// own mail app addressed to support. A field this client knows nothing of
// is written as null, never left out, so a reader can tell "not known" from
// "not asked". The shape has no field for a pairing key, a fingerprint, an
// address, a Wi-Fi name or a host's name: hosts are aliases, and a
// satellite's own snapshot is the document it scrubbed for this connection.

import Foundation

package enum DiagnosticsBundleVersion {
    package static let current = 1
}

package enum DiagnosticsMailAddress {
    package static let support = "support@tinkernorth.com"
}

package struct BundleApp: Equatable, Encodable {
    package let name: String
    package let version: String
    package let build: String

    package init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }
}

package struct BundleDevice: Equatable, Encodable {
    /// The hardware's model identifier, "iPhone18,1".
    package let model: String
    /// "iOS 26.1".
    package let os: String
    package let conditions: BundleConditions

    package init(model: String, os: String, conditions: BundleConditions = .unknown) {
        self.model = model
        self.os = os
        self.conditions = conditions
    }

    private enum CodingKeys: String, CodingKey {
        case model, os, battery, thermal, powerSave, wifi, usbHost
    }

    /// iOS tells an app nothing of its Wi-Fi link or of a USB host, so both
    /// are null on every iPhone and iPad.
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(os, forKey: .os)
        try container.encode(conditions.battery, forKey: .battery)
        try container.encode(conditions.thermal?.rawValue, forKey: .thermal)
        try container.encode(conditions.powerSave, forKey: .powerSave)
        try container.encodeNil(forKey: .wifi)
        try container.encodeNil(forKey: .usbHost)
    }
}

package struct BundleControllerDb: Equatable, Encodable {
    package let bundledVersion: Int
    package let activeVersion: Int
    package let source: ControllerDbSource
    package let lastCheckAtMs: Int64?
    package let lastCheckResult: ControllerDbCheckResult?

    package init(
        bundledVersion: Int,
        activeVersion: Int,
        source: ControllerDbSource,
        lastCheckAtMs: Int64?,
        lastCheckResult: ControllerDbCheckResult?
    ) {
        self.bundledVersion = bundledVersion
        self.activeVersion = activeVersion
        self.source = source
        self.lastCheckAtMs = lastCheckAtMs
        self.lastCheckResult = lastCheckResult
    }

    private enum CodingKeys: String, CodingKey {
        case bundledVersion, activeVersion, source, lastCheckAt, lastCheckResult
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundledVersion, forKey: .bundledVersion)
        try container.encode(activeVersion, forKey: .activeVersion)
        try container.encode(source.rawValue, forKey: .source)
        try container.encode(lastCheckAtMs.map(bundleInstant), forKey: .lastCheckAt)
        try container.encode(lastCheckResult?.rawValue, forKey: .lastCheckResult)
    }
}

/// How the pad reaches this client: GameController's reading, Dish's own
/// over CoreBluetooth, or the on-screen controller the app draws.
package enum BundlePath: String, Equatable {
    case gameController
    case bluetooth
    case virtual
}

/// What the system said of the pad: the ids where Dish reads it itself, the
/// product's name, and the category GameController gives.
package struct BundleHardware: Equatable, Encodable {
    package let vid: String?
    package let pid: String?
    package let product: String
    package let category: String?

    package init(vid: String?, pid: String?, product: String, category: String?) {
        self.vid = vid
        self.pid = pid
        self.product = product
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case vid, pid, product, category
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vid, forKey: .vid)
        try container.encode(pid, forKey: .pid)
        try container.encode(product, forKey: .product)
        try container.encode(category, forKey: .category)
    }
}

/// One person-confirmed test of a pad.
package struct BundleOutcome: Equatable, Encodable {
    package let test: String
    package let result: String
    package let atMs: Int64

    package init(test: String, result: String, atMs: Int64) {
        self.test = test
        self.result = result
        self.atMs = atMs
    }
}

package struct BundleController: Equatable, Encodable {
    /// Nil when no record matched.
    package let record: String?
    package let verification: String?
    /// Nil for the on-screen controller, which no link carries.
    package let transport: ControllerTransport?
    package let path: BundlePath
    /// Nil for the on-screen controller, which has no hardware to tell of.
    package let hardware: BundleHardware?
    package let outcomes: [BundleOutcome]
    package let input: BundleInput?
    package let output: BundleOutput?
    /// Nil where Dish does not read the pad over Bluetooth itself.
    package let bluetooth: BundleBluetooth?

    package init(
        record: String?,
        verification: String?,
        transport: ControllerTransport?,
        path: BundlePath,
        hardware: BundleHardware?,
        outcomes: [BundleOutcome] = [],
        input: BundleInput? = nil,
        output: BundleOutput? = nil,
        bluetooth: BundleBluetooth? = nil
    ) {
        self.record = record
        self.verification = verification
        self.transport = transport
        self.path = path
        self.hardware = hardware
        self.outcomes = outcomes
        self.input = input
        self.output = output
        self.bluetooth = bluetooth
    }

    private enum CodingKeys: String, CodingKey {
        case record, verification, transport, path, hardware, lastFeedback, outcomes, input, output, bluetooth
    }

    /// iOS keeps no account of a pad's last feedback beyond its output
    /// lanes, so `lastFeedback` is null.
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(record, forKey: .record)
        try container.encode(verification, forKey: .verification)
        try container.encode(transport?.rawValue, forKey: .transport)
        try container.encode(path.rawValue, forKey: .path)
        try container.encode(hardware, forKey: .hardware)
        try container.encodeNil(forKey: .lastFeedback)
        try container.encode(outcomes, forKey: .outcomes)
        try container.encode(input, forKey: .input)
        try container.encode(output, forKey: .output)
        try container.encode(bluetooth, forKey: .bluetooth)
    }
}

/// What a host granted this client; iOS asks for none of the three.
package struct BundleGrants: Equatable, Encodable {
    package let mic: Bool
    package let speaker: Bool
    package let hapticAudio: Bool

    package init(mic: Bool, speaker: Bool, hapticAudio: Bool) {
        self.mic = mic
        self.speaker = speaker
        self.hapticAudio = hapticAudio
    }
}

package struct BundleHost: Equatable, Encodable {
    /// "Host 1", "Host 2": never the host's own name.
    package let alias: String
    package let kind: String
    package let version: String?
    package let protocolVersion: Int?
    package let link: String
    package let grants: BundleGrants
    /// The client's own view of the session; nil while none is up.
    package let session: BundleSession?
    /// What the host said of itself, or the client's copy and why.
    package let snapshot: BundleHostSnapshot

    package init(
        alias: String,
        kind: String,
        version: String?,
        protocolVersion: Int?,
        link: String,
        grants: BundleGrants,
        session: BundleSession? = nil,
        snapshot: BundleHostSnapshot = .none
    ) {
        self.alias = alias
        self.kind = kind
        self.version = version
        self.protocolVersion = protocolVersion
        self.link = link
        self.grants = grants
        self.session = session
        self.snapshot = snapshot
    }

    private enum CodingKeys: String, CodingKey {
        case alias, kind, version
        case protocolVersion = "protocol"
        case link, grants, session, snapshot, snapshotError
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(alias, forKey: .alias)
        try container.encode(kind, forKey: .kind)
        try container.encode(version, forKey: .version)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(link, forKey: .link)
        try container.encode(grants, forKey: .grants)
        try container.encode(session, forKey: .session)
        try container.encode(snapshot.snapshot, forKey: .snapshot)
        try container.encode(snapshot.error?.rawValue, forKey: .snapshotError)
    }
}

package struct BundleLogLine: Equatable, Encodable {
    package let atMs: Int64
    package let tag: String
    package let message: String

    package init(atMs: Int64, tag: String, message: String) {
        self.atMs = atMs
        self.tag = tag
        self.message = message
    }
}

package struct DiagnosticsBundle: Equatable, Encodable {
    package let createdAtMs: Int64
    /// The person's own words; nil for a file sent without a report.
    package let report: BundleReport?
    package let app: BundleApp
    package let device: BundleDevice
    package let controllerDb: BundleControllerDb
    package let controllers: [BundleController]
    package let hosts: [BundleHost]
    package let log: [BundleLogLine]

    package init(
        createdAtMs: Int64,
        app: BundleApp,
        device: BundleDevice,
        controllerDb: BundleControllerDb,
        controllers: [BundleController],
        hosts: [BundleHost],
        log: [BundleLogLine],
        report: BundleReport? = nil
    ) {
        self.createdAtMs = createdAtMs
        self.report = report
        self.app = app
        self.device = device
        self.controllerDb = controllerDb
        self.controllers = controllers
        self.hosts = hosts
        self.log = log
    }

    private enum CodingKeys: String, CodingKey {
        case bundle, createdAt, report, app, device, controllerDb, controllers, hosts, log
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(DiagnosticsBundleVersion.current, forKey: .bundle)
        try container.encode(bundleInstant(createdAtMs), forKey: .createdAt)
        try container.encode(report, forKey: .report)
        try container.encode(app, forKey: .app)
        try container.encode(device, forKey: .device)
        try container.encode(controllerDb, forKey: .controllerDb)
        try container.encode(controllers, forKey: .controllers)
        try container.encode(hosts, forKey: .hosts)
        try container.encode(log, forKey: .log)
    }
}

/// The file's bytes, keys sorted and indented so a person can read it
/// before pressing Send. Every field is a string, a number, a boolean or
/// null, which `JSONEncoder` always writes.
package func encodeDiagnosticsBundle(_ bundle: DiagnosticsBundle) -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let written = try? encoder.encode(bundle)
    return written ?? Data()
}

/// An instant as the bundle writes it: UTC, to the second, "2026-11-19T21:04:11Z".
package func bundleInstant(_ ms: Int64) -> String {
    Date(timeIntervalSince1970: Double(ms) / 1000).ISO8601Format()
}

/// `dish-diagnostics-<app>-<yyyyMMdd-HHmmss>.json`, the moment in `timeZone`.
package func diagnosticsFileName(app: String, atMs: Int64, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let stamp = formatter.string(from: Date(timeIntervalSince1970: Double(atMs) / 1000))
    return "dish-diagnostics-\(app)-\(stamp).json"
}
