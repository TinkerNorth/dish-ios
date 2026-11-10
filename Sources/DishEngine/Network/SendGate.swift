// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import CryptoKit
import Darwin
import DishCore
import Foundation
import Synchronization

/// The satellite session's send gate: a flag one sender holds at a time,
/// taken with a compare-exchange and yielded on while another holds it, the
/// satellite's counter-order rule. A holder claims a counter, seals and
/// sends, so the session's datagrams leave in counter order; a re-key and a
/// socket change hold it too. Nothing waits on it in the kernel.
package final class SendGate: Sendable {
    private let flag = Atomic<Int32>(0)

    package init() {}

    func take() {
        while !flag.compareExchange(expected: 0, desired: 1, ordering: .acquiring).exchanged {
            sched_yield()
        }
    }

    func release() {
        flag.store(0, ordering: .releasing)
    }

    /// Whether a sender holds it now; a snapshot, for the tests.
    var isTaken: Bool {
        flag.load(ordering: .relaxed) != 0
    }

    func hold<T>(_ body: () throws -> T) rethrows -> T {
        take()
        defer { release() }
        return try body()
    }
}

/// The key and token one session PUT installed, as one object, so a re-key
/// swaps both at once.
final class SessionGeneration: Sendable {
    let key: SymmetricKey
    let token: UInt32

    init(key: SymmetricKey, token: UInt32) {
        self.key = key
        self.token = token
    }
}

/// `sendto`'s shape, so a test can stand in for the socket.
package typealias SocketSend = @Sendable (
    _ fd: Int32,
    _ bytes: UnsafeRawPointer?,
    _ count: Int,
    _ flags: Int32,
    _ address: UnsafePointer<sockaddr>?,
    _ addressLength: socklen_t
) -> Int

/// The socket's own `sendto`.
package func systemSend(
    _ fd: Int32,
    _ bytes: UnsafeRawPointer?,
    _ count: Int,
    _ flags: Int32,
    _ address: UnsafePointer<sockaddr>?,
    _ addressLength: socklen_t
) -> Int {
    Darwin.sendto(fd, bytes, count, flags, address, addressLength)
}

/// Where the socket sends, an IPv4 address and port in network order packed
/// into one word with a presence bit, so a sender reads it whole under the
/// gate.
struct SendTarget: Equatable {
    private static let present: Int64 = 1 << 48

    let address: UInt32
    let port: UInt16

    init(address: UInt32, port: UInt16) {
        self.address = address
        self.port = port
    }

    /// Nil for the empty word.
    init?(packed word: Int64) {
        guard word & Self.present != 0 else { return nil }
        self.init(address: UInt32(truncatingIfNeeded: word), port: UInt16(truncatingIfNeeded: word >> 32))
    }

    var packed: Int64 {
        Self.present | Int64(port) << 32 | Int64(address)
    }

    var sockaddr: sockaddr_in {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port
        addr.sin_addr = in_addr(s_addr: address)
        return addr
    }

    /// `host` as an IPv4 literal and `udpPort`, both in network order; nil
    /// for a host that is not one.
    static func resolve(host: String, udpPort: UInt16) -> SendTarget? {
        var address = in_addr()
        guard host.withCString({ inet_pton(AF_INET, $0, &address) }) == 1 else { return nil }
        return SendTarget(address: address.s_addr, port: udpPort.bigEndian)
    }
}
