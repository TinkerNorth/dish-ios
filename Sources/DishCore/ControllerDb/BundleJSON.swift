// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Any JSON document, kept as it arrived: a host's own snapshot rides the
/// bundle whole, so a field this client has never heard of still reaches
/// the reader.
package indirect enum JSONValue: Equatable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    package init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let flag = try? container.decode(Bool.self) {
            self = .bool(flag)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let text = try? container.decode(String.self) {
            self = .string(text)
        } else if let items = try? container.decode([JSONValue].self) {
            self = .array(items)
        } else {
            self = try .object(container.decode([String: JSONValue].self))
        }
    }

    package func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(flag): try container.encode(flag)
        case let .number(number): try container.encode(number)
        case let .string(text): try container.encode(text)
        case let .array(items): try container.encode(items)
        case let .object(fields): try container.encode(fields)
        }
    }

    /// The text, or nil for any other kind.
    package var string: String? {
        guard case let .string(text) = self else { return nil }
        return text
    }

    /// A field of an object, or nil for any other kind or a field it lacks.
    package subscript(key: String) -> JSONValue? {
        guard case let .object(fields) = self else { return nil }
        return fields[key]
    }
}

/// A body read as one JSON object; nil for anything else (an array, a
/// scalar, or bytes that are not JSON).
package func decodeJSONObject(_ data: Data) -> JSONValue? {
    guard let value = try? JSONDecoder().decode(JSONValue.self, from: data), case .object = value else { return nil }
    return value
}

extension JSONValue {
    /// An optional text as JSON: null when absent.
    static func text(_ value: String?) -> JSONValue {
        value.map(JSONValue.string) ?? .null
    }

    /// An optional integer as JSON: null when absent.
    static func integer(_ value: Int?) -> JSONValue {
        value.map { .number(Double($0)) } ?? .null
    }

    /// An optional flag as JSON: null when absent.
    static func flag(_ value: Bool?) -> JSONValue {
        value.map(JSONValue.bool) ?? .null
    }
}
