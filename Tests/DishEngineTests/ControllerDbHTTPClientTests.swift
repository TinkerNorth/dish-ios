// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Synchronization
import XCTest
@testable import DishEngine

/// The website as `URLSession` sees it in these tests: each request kept,
/// each answered from a table by its path.
final class RecordingURLProtocol: URLProtocol {
    struct Reply {
        let status: Int
        let body: Data
        let headers: [String: String]
    }

    private static let log = Mutex<[URLRequest]>([])
    private static let replies = Mutex<[String: Reply]>([:])

    static var requests: [URLRequest] {
        log.withLock { $0 }
    }

    static func reset(_ table: [String: Reply]) {
        log.withLock { $0 = [] }
        replies.withLock { $0 = table }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.log.withLock { $0.append(request) }
        let path = request.url?.path() ?? ""
        let reply = Self.replies.withLock { $0[path] } ?? Reply(status: 404, body: Data(), headers: [:])
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers) else
        {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// The check's requests on the wire: the manifest by its path with our
/// ETag, a 304 as nothing new, a file by its path; no query, no cookie,
/// nothing that names the device.
final class ControllerDbHTTPClientTests: XCTestCase {

    private func client() throws -> ControllerDbHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingURLProtocol.self]
        return try ControllerDbHTTPClient(base: XCTUnwrap(URL(string: ControllerDbSchedule.baseURLString)), configuration: configuration)
    }

    func testTheManifestIsAskedForByItsPathWithTheETag() async throws {
        RecordingURLProtocol.reset(["/controllers/v1/manifest.json": .init(status: 304, body: Data(), headers: [:])])
        let reply = try await client().manifest(etag: "\"v1\"")
        XCTAssertEqual(reply, .notModified)
        let request = try XCTUnwrap(RecordingURLProtocol.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://dish.tinkernorth.com/controllers/v1/manifest.json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "If-None-Match"), "\"v1\"")
        XCTAssertNil(request.url?.query())
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func testAManifestComesWithItsETag() async throws {
        let body = Data("{}".utf8)
        RecordingURLProtocol.reset(["/controllers/v1/manifest.json": .init(status: 200, body: body, headers: ["ETag": "\"v2\""])])
        let reply = try await client().manifest(etag: nil)
        XCTAssertEqual(reply, .body(body, etag: "\"v2\""))
        XCTAssertNil(RecordingURLProtocol.requests.first?.value(forHTTPHeaderField: "If-None-Match"), "no ETag is sent before one is known")
    }

    func testAFileIsAskedForByItsPublishedPath() async throws {
        RecordingURLProtocol.reset(["/controllers/v1/strings/pt-BR.json": .init(status: 200, body: Data("{}".utf8), headers: [:])])
        let data = try await client().file("strings/pt-BR.json")
        XCTAssertEqual(data, Data("{}".utf8))
        XCTAssertEqual(
            RecordingURLProtocol.requests.first?.url?.absoluteString,
            "https://dish.tinkernorth.com/controllers/v1/strings/pt-BR.json"
        )
    }

    func testAFileThatIsNotThereIsNoFile() async throws {
        RecordingURLProtocol.reset([:])
        let data = try await client().file("controllers.json")
        XCTAssertNil(data)
    }
}
