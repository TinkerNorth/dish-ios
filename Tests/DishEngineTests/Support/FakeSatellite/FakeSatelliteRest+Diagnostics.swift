// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// How the fake's connection diagnostics route answers.
enum FakeDiagnosticsRoute {
    /// No such route: a satellite older than 2.3.0.
    case absent
    /// The route, answering 404 as for a connection it does not know.
    case unknownConnection
    /// This document, with 200.
    case answer(String)
    /// This document, after a wait the client may not sit out.
    case slow(String, seconds: TimeInterval)
}

/// `GET /api/connections/{id}/diagnostics`, behind the same proof as the
/// session routes.
extension FakeSatelliteRest {
    func connectionDiagnostics(_ request: FakeSatelliteHttp.Request, id: String) -> FakeSatelliteHttp.Response {
        let route = store.with { state -> FakeDiagnosticsRoute in
            state.diagnosticsGets += 1
            return state.diagnosticsRoute
        }
        if case .absent = route { return FakeSatelliteHttp.json(404, ["error": "unknown route"]) }
        if case let .unauthorized(code) = authenticate(request, body: [:]) { return unauthorized(code) }
        guard id == connectionId else { return notFound() }
        switch route {
        case .absent, .unknownConnection:
            return notFound()
        case let .answer(document):
            return FakeSatelliteHttp.json(200, raw: document)
        case let .slow(document, seconds):
            Thread.sleep(forTimeInterval: seconds)
            return FakeSatelliteHttp.json(200, raw: document)
        }
    }
}
