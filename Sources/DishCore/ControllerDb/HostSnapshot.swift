// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// What a host says of itself in the support file (dish-website
// `docs/diagnostics-bundle.md`, "The hosts, from both ends"): a Satellite of
// 2.3.0 or later answers its connection's diagnostics route, and the client
// embeds the answer whole; an older one, told by the version its
// capabilities gave and never asked, or one that could not answer, gets
// what the client already fetched from it, marked as such; a
// Moonlight host gets the fields the client parsed from its serverinfo,
// never its hostname.

import Foundation

package enum HostSnapshotPolicy {
    /// How long the client waits for a host's snapshot before it gives up.
    package static let timeoutSeconds: TimeInterval = 2
    /// The route's document, as the satellite names it.
    package static let connectionFormat = "satellite-connection-diagnostics.v1"
    /// What the client already fetched from a satellite, as the bundle names it.
    package static let capabilitiesFormat = "satellite-capabilities"
    /// What the client parsed from a Moonlight host's serverinfo.
    package static let moonlightFormat = "moonlight-serverinfo"
    /// The first Satellite that serves the connection's diagnostics route.
    package static let firstServingVersion = [2, 3, 0]
}

/// How the diagnostics route answered, as the gateway saw it.
package enum SnapshotReply: Equatable {
    /// An HTTP status and its body.
    case answered(status: Int, body: Data)
    /// No answer within the timeout.
    case timedOut
    /// No answer at all: refused, unreachable, or a pin that did not match.
    case unreachable
}

/// Why the file holds the client's own copy rather than the host's word.
package enum SnapshotError: String, Equatable {
    case offline
    case unauthorized
    /// The satellite's version, from its capabilities, is below 2.3.0.
    case olderSatellite
    case timeout
    /// A satellite of 2.3.0 or later that does not know this connection.
    case unknownConnection
    /// A server error, or a success whose body is not one JSON object.
    case badReply
}

/// The route's answer read: the document to embed, or why there is none.
package enum SnapshotOutcome: Equatable {
    case snapshot(JSONValue)
    case failed(SnapshotError)
}

package func snapshotOutcome(_ reply: SnapshotReply) -> SnapshotOutcome {
    switch reply {
    case let .answered(status, body): answeredOutcome(status: status, body: body)
    case .timedOut: .failed(.timeout)
    case .unreachable: .failed(.offline)
    }
}

/// A 404 from a satellite that serves the route is a connection it does
/// not know or that is another device's; a refused proof is unauthorized; a
/// success whose body is not one JSON object, or any other status, is a bad
/// reply.
private func answeredOutcome(status: Int, body: Data) -> SnapshotOutcome {
    switch status {
    case 200 ..< 300: decodeJSONObject(body).map(SnapshotOutcome.snapshot) ?? .failed(.badReply)
    case 401, 403: .failed(.unauthorized)
    case 404: .failed(.unknownConnection)
    default: .failed(.badReply)
    }
}

/// One host entry's `snapshot` and `snapshotError`.
package struct BundleHostSnapshot: Equatable {
    package let snapshot: JSONValue?
    package let error: SnapshotError?

    package init(snapshot: JSONValue?, error: SnapshotError?) {
        self.snapshot = snapshot
        self.error = error
    }

    /// A host the client asked nothing of.
    package static let none = BundleHostSnapshot(snapshot: nil, error: nil)
}

/// Whether the satellite is asked for its snapshot: not when the version
/// its capabilities gave is below 2.3.0; a satellite whose version is
/// unknown is asked, and its answer decides.
package func asksForConnectionDiagnostics(_ cached: SatelliteCapabilitiesFacts?) -> Bool {
    guard let version = cached.flatMap({ releaseNumbers($0.serverVersion) }) else { return true }
    return !version.lexicographicallyPrecedes(HostSnapshotPolicy.firstServingVersion)
}

/// "2.3.0" as [2, 3, 0], each part read to its first non-digit ("0-rc1" is
/// 0) and a missing part as 0 ("2.3" is [2, 3, 0]); nil for a version that
/// does not open with a number.
private func releaseNumbers(_ version: String) -> [Int]? {
    let parts = version.split(separator: ".").map { Int($0.prefix { $0.isNumber }) }
    guard case .some(.some) = parts.first else { return nil }
    let read = parts.map { $0 ?? 0 }
    let missing = max(0, HostSnapshotPolicy.firstServingVersion.count - read.count)
    return read + Array(repeating: 0, count: missing)
}

/// A satellite's entry: an older satellite's copy marked as such; else the
/// route's document when it answered, or the copy the client already holds
/// with the reason. A satellite with no live link was not asked, and reads
/// offline.
package func satelliteSnapshot(_ outcome: SnapshotOutcome?, cached: SatelliteCapabilitiesFacts?) -> BundleHostSnapshot {
    let fallback = cached.map(satelliteCapabilitiesDocument)
    guard asksForConnectionDiagnostics(cached) else { return BundleHostSnapshot(snapshot: fallback, error: .olderSatellite) }
    switch outcome {
    case let .snapshot(document): return BundleHostSnapshot(snapshot: document, error: nil)
    case let .failed(error): return BundleHostSnapshot(snapshot: fallback, error: error)
    case nil: return BundleHostSnapshot(snapshot: fallback, error: .offline)
    }
}

/// A Moonlight host has no route: its serverinfo as the client parsed it,
/// or offline when it was never read.
package func moonlightSnapshot(_ info: MoonlightServerInfo?) -> BundleHostSnapshot {
    guard let info else { return BundleHostSnapshot(snapshot: nil, error: .offline) }
    return BundleHostSnapshot(snapshot: moonlightServerInfoDocument(info), error: nil)
}

// MARK: - The client's own copies

/// One backend as `/api/server/capabilities` lists it, the fields a
/// maintainer reads; each is nil where an older satellite leaves it out.
package struct CapabilityBackendFact: Equatable {
    package let id: String
    package let available: Bool?
    package let errorCode: String?
    package let lifecycle: String?
    package let driverVersion: String?
    package let bundledVersion: String?
    package let versionState: String?
    package let audio: Bool?

    package init(
        id: String,
        available: Bool?,
        errorCode: String? = nil,
        lifecycle: String? = nil,
        driverVersion: String? = nil,
        bundledVersion: String? = nil,
        versionState: String? = nil,
        audio: Bool? = nil
    ) {
        self.id = id
        self.available = available
        self.errorCode = errorCode
        self.lifecycle = lifecycle
        self.driverVersion = driverVersion
        self.bundledVersion = bundledVersion
        self.versionState = versionState
        self.audio = audio
    }
}

/// The host's controller-audio block, as it granted it.
package struct CapabilityAudioFact: Equatable {
    package let enabled: Bool
    package let mic: Bool
    package let speaker: Bool
    package let hapticAudio: Bool

    package init(enabled: Bool, mic: Bool, speaker: Bool, hapticAudio: Bool) {
        self.enabled = enabled
        self.mic = mic
        self.speaker = speaker
        self.hapticAudio = hapticAudio
    }
}

/// What the client last fetched from a satellite: its capabilities and its
/// catalog's schema version.
package struct SatelliteCapabilitiesFacts: Equatable {
    package let serverVersion: String
    /// The newest protocol the satellite speaks.
    package let protocolVersion: Int
    package let backends: [CapabilityBackendFact]
    /// Nil on a satellite whose capabilities carry no audio block.
    package let controllerAudio: CapabilityAudioFact?
    /// Nil until the catalog was read.
    package let catalogVersion: Int?

    package init(
        serverVersion: String,
        protocolVersion: Int,
        backends: [CapabilityBackendFact],
        controllerAudio: CapabilityAudioFact?,
        catalogVersion: Int?
    ) {
        self.serverVersion = serverVersion
        self.protocolVersion = protocolVersion
        self.backends = backends
        self.controllerAudio = controllerAudio
        self.catalogVersion = catalogVersion
    }
}

/// The capabilities copy, as the contract shapes it. The protocol range
/// opens at the floor every satellite speaks, since capabilities name only
/// the newest; an empty server version is one the satellite did not say.
package func satelliteCapabilitiesDocument(_ facts: SatelliteCapabilitiesFacts) -> JSONValue {
    let range: JSONValue = .array([.integer(ProtocolConstants.protocolVersionMin), .integer(facts.protocolVersion)])
    return .object([
        "format": .string(HostSnapshotPolicy.capabilitiesFormat),
        "serverVersion": .text(facts.serverVersion.isEmpty ? nil : facts.serverVersion),
        "protocol": range,
        "backends": .array(facts.backends.map(backendDocument)),
        "controllerAudio": facts.controllerAudio.map(audioDocument) ?? .null,
        "catalogVersion": .integer(facts.catalogVersion)
    ])
}

private func backendDocument(_ backend: CapabilityBackendFact) -> JSONValue {
    .object([
        "id": .string(backend.id),
        "available": .flag(backend.available),
        "errorCode": .text(backend.errorCode),
        "lifecycle": .text(backend.lifecycle),
        "driverVersion": .text(backend.driverVersion),
        "bundledVersion": .text(backend.bundledVersion),
        "versionState": .text(backend.versionState),
        "audio": .flag(backend.audio)
    ])
}

private func audioDocument(_ audio: CapabilityAudioFact) -> JSONValue {
    .object([
        "enabled": .bool(audio.enabled),
        "mic": .bool(audio.mic),
        "speaker": .bool(audio.speaker),
        "hapticAudio": .bool(audio.hapticAudio)
    ])
}

/// The host's version alone, never what names the host or where it is (no
/// hostname, unique id, MAC or address). The state and the pairing status
/// are null: the plaintext serverinfo the client reads reports every host
/// free and every caller unpaired.
package func moonlightServerInfoDocument(_ info: MoonlightServerInfo) -> JSONValue {
    .object([
        "format": .string(HostSnapshotPolicy.moonlightFormat),
        "appVersion": .text(info.appVersion),
        "state": .null,
        "pairStatus": .null
    ])
}

/// A host's document with every word that names the host or where it is
/// replaced by its alias, in keys and values alike; an empty word is left alone.
package func scrubbedSnapshot(_ document: JSONValue, naming words: [String], alias: String) -> JSONValue {
    let names = words.filter { !$0.isEmpty }
    guard !names.isEmpty else { return document }
    return scrubbed(document, names: names, alias: alias)
}

private func scrubbed(_ value: JSONValue, names: [String], alias: String) -> JSONValue {
    switch value {
    case .null, .bool, .number: value
    case let .string(text): .string(replacing(names, in: text, with: alias))
    case let .array(items): .array(items.map { scrubbed($0, names: names, alias: alias) })
    case let .object(fields): .object(scrubbedFields(fields, names: names, alias: alias))
    }
}

private func scrubbedFields(_ fields: [String: JSONValue], names: [String], alias: String) -> [String: JSONValue] {
    var out: [String: JSONValue] = [:]
    for (key, value) in fields {
        out[replacing(names, in: key, with: alias)] = scrubbed(value, names: names, alias: alias)
    }
    return out
}

/// The longest name first, so a name inside another is not left half replaced.
private func replacing(_ names: [String], in text: String, with alias: String) -> String {
    names.sorted { $0.count > $1.count }.reduce(text) { $0.replacingOccurrences(of: $1, with: alias) }
}
