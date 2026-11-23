// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The website's controller data, the check's one IO boundary: the
/// manifest with `If-None-Match`, then each file it names. A test hands in
/// a recorder.
package protocol ControllerDbGateway: Sendable {
    func manifest(etag: String?) async -> ManifestReply
    /// Nil for no answer or any status but 200.
    func file(_ path: String) async -> Data?
}

/// The gateway over HTTPS to `dish.tinkernorth.com/controllers/v1/`, in the
/// shape of the satellite's `HTTPClient`: an ephemeral `URLSession` with no
/// cookies and no cache of its own, the ETag being ours to send. A request
/// carries no query and no identifier, only its path, the system's default
/// user agent and one language for every device. A gap of 15 seconds ends a
/// request, and so does a whole minute, so a host that trickles bytes cannot
/// hold the check open.
package final class ControllerDbHTTPClient: ControllerDbGateway {
    private static let timeoutSeconds: TimeInterval = 15
    private static let transferSeconds: TimeInterval = 60
    /// One value for every device: the system's would name the person's languages.
    static let acceptLanguage = "*"

    private let session: URLSession
    private let base: URL

    package init(base: URL, configuration: URLSessionConfiguration = .ephemeral) {
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = Self.timeoutSeconds
        configuration.timeoutIntervalForResource = Self.transferSeconds
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
        self.base = base
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    package func manifest(etag: String?) async -> ManifestReply {
        let request = manifestRequest(etag: etag)
        guard let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse else {
            return .unreachable
        }
        return manifestReply(status: http.statusCode, body: data, etag: http.value(forHTTPHeaderField: "ETag"))
    }

    package func file(_ path: String) async -> Data? {
        let request = fileRequest(path)
        guard let (data, response) = try? await session.data(for: request) else { return nil }
        let succeeded = (response as? HTTPURLResponse)?.statusCode == 200
        return succeeded ? data : nil
    }
}

extension ControllerDbHTTPClient {
    func manifestRequest(etag: String?) -> URLRequest {
        var request = fileRequest(ControllerDbFiles.manifest)
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        return request
    }

    func fileRequest(_ path: String) -> URLRequest {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.setValue(Self.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        return request
    }
}

/// A gateway that never answers: the model a test or a preview builds
/// outside the scene, which must never reach the website.
package final class OfflineControllerDbGateway: ControllerDbGateway {
    package init() {}

    package func manifest(etag _: String?) async -> ManifestReply {
        .unreachable
    }

    package func file(_: String) async -> Data? {
        nil
    }
}
