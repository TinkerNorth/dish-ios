// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The INPUT frame a session sends, by the version it settled on: the
/// extended-buttons word behind the report from protocol 4, never before.
@MainActor
final class SatelliteClientInputFrameTests: XCTestCase {

    func testTheInputFrameShapeFollowsTheSettledVersion() throws {
        let (fd, port) = try XCTUnwrap(DataPlaneTestHelpers.bindLoopbackSocket())
        defer { close(fd) }
        let client = try XCTUnwrap(DataPlaneTestHelpers.makeClient(port: port))
        defer { client.closeSocket() }
        let report = GamepadReport(buttons: 0x0001, extButtons: 0x0000_1003)

        client.sendReport(controllerIndex: 2, report: report)
        let versionOne = try XCTUnwrap(DataPlaneTestHelpers.receiveDatagram(fd: fd))
        XCTAssertEqual(
            DataPlaneTestHelpers.openUplink(versionOne)?.inner.payload.count,
            13,
            "a session settled on 1 streams the 13-byte frame whatever the word"
        )

        XCTAssertTrue(client.setConnectionParams(
            host: "127.0.0.1",
            udpPort: port,
            token: DataPlaneTestHelpers.testToken,
            sessionKey: DataPlaneTestHelpers.testKey,
            protocolVersion: 3
        ))
        client.sendReport(controllerIndex: 2, report: report)
        let versionThree = try XCTUnwrap(DataPlaneTestHelpers.receiveDatagram(fd: fd))
        XCTAssertEqual(
            DataPlaneTestHelpers.openUplink(versionThree)?.inner.payload.count,
            13,
            "a satellite on 3 is sent exactly what it was sent before"
        )

        XCTAssertTrue(client.setConnectionParams(
            host: "127.0.0.1",
            udpPort: port,
            token: DataPlaneTestHelpers.testToken,
            sessionKey: DataPlaneTestHelpers.testKey,
            protocolVersion: 4
        ))
        client.sendReport(controllerIndex: 2, report: report)
        let versionFour = try XCTUnwrap(DataPlaneTestHelpers.receiveDatagram(fd: fd))
        let inner = try XCTUnwrap(DataPlaneTestHelpers.openUplink(versionFour)?.inner)
        XCTAssertEqual(inner.payload.count, 17, "a session settled on 4 carries the extended-buttons word")
        XCTAssertEqual([UInt8](inner.payload.suffix(4)), [0x03, 0x10, 0x00, 0x00])
    }
}
