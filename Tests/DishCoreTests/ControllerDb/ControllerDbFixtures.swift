// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// Small controller database files in the shape dish-website publishes,
/// each the smallest that walks one branch of the readers.
enum ControllerDbFixtures {

    /// The 2026 Steam Controller over Bluetooth, as dbVersion 1 carries it,
    /// with one issue on Bluetooth for any device and one on USB.
    static let tritonRecord = """
    {
      "schema": 1,
      "id": "valve-steam-controller-2026-bluetooth",
      "requires": { "families": ["steamTriton"], "ops": [] },
      "identity": { "usb": [], "bluetooth": ["28DE:1303"] },
      "input": {
        "protocol": { "ref": "steamTriton", "streamsUnprompted": false, "fields": { "reserved": true } },
        "direct": { "rule": "auto" },
        "capabilities": { "motion": true, "touchpad": false, "trackpads": 2, "battery": false, "extendedButtons": true }
      },
      "output": { "route": "setReport", "init": { "kind": "steamTritonQuiet" }, "capabilities": { "rumble": true } },
      "expect": { "endpoints": { "in": true, "out": false } },
      "lifecycle": { "reserved": "a later schema's field" },
      "support": {
        "verification": { "state": "verified", "transport": "bluetooth" },
        "issues": [
          { "id": "triton-ble-lag", "transport": "bluetooth", "lane": "input", "status": "open" },
          { "id": "triton-usb-only", "transport": "usb", "status": "open" }
        ],
        "sources": ["fixture"]
      }
    }
    """

    static let dualSenseRecord = """
    {
      "schema": 1,
      "id": "sony-dualsense",
      "identity": { "usb": ["054c:0ce6"], "bluetooth": [] },
      "input": { "protocol": { "ref": "dualsense" }, "direct": { "rule": "auto" } },
      "support": { "verification": { "state": "imported" } }
    }
    """

    /// A database of `records`, at `version`, under `schema`.
    static func database(_ records: [String], version: Int = 1, schema: Int = 1) -> Data {
        Data("{ \"schema\": \(schema), \"dbVersion\": \(version), \"records\": [\(records.joined(separator: ","))] }".utf8)
    }

    static let english = Data("""
    {
      "controller.valve-steam-controller-2026-bluetooth.name": "Valve Steam Controller (2026, Bluetooth)",
      "issue.triton-ble-lag.title": "Input arrives late",
      "issue.triton-ble-lag.body": "Being investigated.",
      "family.steamTriton.name": "Steam Controller (2026) protocol"
    }
    """.utf8)

    static let german = Data("""
    { "issue.triton-ble-lag.title": "Eingaben kommen spät an", "family.steamTriton.name": "Steam-Controller-Protokoll (2026)" }
    """.utf8)

    /// A manifest that vouches for exactly `files`, at `version`.
    static func manifest(for files: [String: Data], version: Int = 1, schema: Int = 1) -> Data {
        let entries = files.keys.sorted().map { path -> String in
            let data = files[path] ?? Data()
            return "\"\(path)\": { \"sha256\": \"\(controllerDbDigest(data))\", \"bytes\": \(data.count) }"
        }
        let body = "{ \"schema\": \(schema), \"dbVersion\": \(version), \"publishedAt\": \"2026-11-19T00:00:00Z\", \"files\": { "
            + entries.joined(separator: ", ") + " } }"
        return Data(body.utf8)
    }

    /// One published version whole: the database, two locales and the
    /// manifest that names them.
    static func publishedFiles(version: Int = 2) -> [String: Data] {
        let data = [
            ControllerDbFiles.controllers: database([tritonRecord, dualSenseRecord], version: version),
            ControllerDbFiles.strings("en"): english,
            ControllerDbFiles.strings("de"): german
        ]
        var files = data
        files[ControllerDbFiles.manifest] = manifest(for: data, version: version)
        return files
    }

    static func publishedManifest(version: Int = 2) throws -> ControllerDbManifest {
        let files = publishedFiles(version: version)
        guard let body = files[ControllerDbFiles.manifest], case let .success(manifest) = decodeControllerDbManifest(body) else {
            throw FixtureError.notAManifest
        }
        return manifest
    }

    enum FixtureError: Error {
        case notAManifest
    }
}
