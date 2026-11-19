// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The one reader of `controllers.json`, schema 1. A file whose schema is not
// 1 is refused whole; a record that does not decode (no id, no family, a
// verification this schema does not name, another schema of its own) is
// left out and the rest stand, as the contract's "a row that does not decode
// is not applied" asks. Every field this reader does not name, the reserved
// ones of section 11 among them, is ignored.

import Foundation

/// Why a file of the database was not taken.
package enum ControllerDbError: Error, Equatable {
    /// Not JSON, or not the shape a schema 1 file has.
    case badJson
    /// `schema` is missing or is not 1.
    case unsupportedSchema
}

package enum ControllerDbSchema {
    package static let version = 1
}

package func decodeControllerDatabase(_ data: Data) -> Result<ControllerDatabase, ControllerDbError> {
    guard let file = try? JSONDecoder().decode(DatabaseFile.self, from: data) else { return .failure(.badJson) }
    guard file.schema == ControllerDbSchema.version else { return .failure(.unsupportedSchema) }
    guard let dbVersion = file.dbVersion, let rows = file.records else { return .failure(.badJson) }
    let records = rows.compactMap(\.record).compactMap(controllerRecord)
    return .success(ControllerDatabase(dbVersion: dbVersion, records: records))
}

// MARK: - The file's shape

private struct DatabaseFile: Decodable {
    let schema: Int?
    let dbVersion: Int?
    let records: [LossyRecord]?
}

/// A record that fails to decode is nil, so it alone is dropped.
private struct LossyRecord: Decodable {
    let record: RecordFile?

    init(from decoder: Decoder) throws {
        record = try? RecordFile(from: decoder)
    }
}

private struct RecordFile: Decodable {
    struct Identity: Decodable {
        let usb: [String]?
        let bluetooth: [String]?
    }

    struct ProtocolRef: Decodable {
        let ref: String
    }

    struct Input: Decodable {
        let `protocol`: ProtocolRef
    }

    struct Verification: Decodable {
        let state: String
    }

    struct Issue: Decodable {
        let id: String
        let device: String?
        let os: [String: OsVersion]?
        let transport: String?
        let status: String?
    }

    /// A platform's version, a number or a string such as "15" or "26.1":
    /// its major version, or nil for one that does not read as a number.
    struct OsVersion: Decodable {
        let major: Int?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Int.self) {
                major = number
                return
            }
            let text = try container.decode(String.self)
            major = text.split(separator: ".").first.flatMap { Int($0) }
        }
    }

    struct Support: Decodable {
        let verification: Verification
        let issues: [Issue]?
    }

    let schema: Int?
    let id: String
    let identity: Identity?
    let input: Input
    let support: Support
}

// MARK: - Into a record

private func controllerRecord(_ file: RecordFile) -> ControllerRecord? {
    let schemaFits = file.schema.map { $0 == ControllerDbSchema.version } ?? true
    guard schemaFits, !file.id.isEmpty else { return nil }
    guard let verification = ControllerVerification(rawValue: file.support.verification.state) else { return nil }
    return ControllerRecord(
        id: file.id,
        usb: (file.identity?.usb ?? []).map { $0.lowercased() },
        bluetooth: (file.identity?.bluetooth ?? []).map { $0.lowercased() },
        family: file.input.protocol.ref,
        verification: verification,
        issues: (file.support.issues ?? []).map(controllerIssue)
    )
}

/// A transport this schema does not name reads as none, so the issue shows
/// on every transport rather than on none; a version that is not a number
/// reads as one no host has, so the issue matches no host on that platform.
private func controllerIssue(_ issue: RecordFile.Issue) -> ControllerIssue {
    ControllerIssue(
        id: issue.id,
        device: issue.device,
        os: (issue.os ?? [:]).mapValues { $0.major ?? unreadableOsVersion },
        transport: issue.transport.flatMap(ControllerTransport.init(rawValue:)),
        open: issue.status == openStatus
    )
}

private let openStatus = "open"
private let unreadableOsVersion = -1
