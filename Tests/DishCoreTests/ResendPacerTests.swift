// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// Android's pacing: a changed state goes out on three ticks in a row, then
/// the stream idles at one keepalive a second; a new change starts over.
final class ResendPacerTests: XCTestCase {

    private static let tick = ResendPacer.tickIntervalNs
    private static let start: UInt64 = 10_000_000_000

    /// Whether each tick resent, the first one carrying `changed` and the
    /// rest unchanged, one tick apart from `start`.
    private func run(_ pacer: inout ResendPacer, ticks: Int, firstChanged: Bool, from start: UInt64 = start) -> [Bool] {
        (0 ..< ticks).map { index in
            let now = start + UInt64(index) * Self.tick
            return pacer.resendDue(changed: firstChanged && index == 0, nowNs: now)
        }
    }

    func testAChangeIsResentOnThreeTicksInARowThenGoesQuiet() {
        var pacer = ResendPacer()
        let sent = run(&pacer, ticks: 6, firstChanged: true)
        XCTAssertEqual(sent, [true, true, true, false, false, false])
    }

    func testAnIdleStreamSendsOneKeepaliveASecond() {
        var pacer = ResendPacer()
        let ticksPerSecond = Int(ResendPacer.keepaliveIntervalNs / Self.tick)
        let sent = run(&pacer, ticks: 3 + ticksPerSecond * 2, firstChanged: true)
        let keepalives = sent.indices.filter { sent[$0] && $0 >= 3 }
        XCTAssertEqual(keepalives, [2 + ticksPerSecond, 2 + ticksPerSecond * 2], "one a second after the burst's last send")
    }

    func testAChangeInsideABurstStartsItOver() {
        var pacer = ResendPacer()
        _ = pacer.resendDue(changed: true, nowNs: Self.start)
        _ = pacer.resendDue(changed: false, nowNs: Self.start + Self.tick)
        let sent = run(&pacer, ticks: 4, firstChanged: true, from: Self.start + Self.tick * 2)
        XCTAssertEqual(sent, [true, true, true, false])
    }

    func testAChangeDuringTheKeepaliveSendsAtOnce() {
        var pacer = ResendPacer()
        _ = run(&pacer, ticks: 5, firstChanged: true)
        XCTAssertTrue(pacer.resendDue(changed: true, nowNs: Self.start + Self.tick * 5))
    }

    func testTheFirstIdleTickOfAFreshPacerSendsAKeepalive() {
        var pacer = ResendPacer()
        XCTAssertTrue(pacer.resendDue(changed: false, nowNs: Self.start))
        XCTAssertFalse(pacer.resendDue(changed: false, nowNs: Self.start + Self.tick))
    }
}
