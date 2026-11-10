// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The UDP under a Moonlight session: the control stream's socket, and the
// pings that keep the host's video and audio ports open. One long-lived
// socket per media stream, and it has to be: the host learns where to send
// from the source address of the ping and streams back to that socket, so a
// throwaway socket per ping tells it a new port every time. Whatever arrives
// on them is read and thrown away; an unread socket fills its buffer and
// starts dropping, which some stacks show the far end as a dead peer.

import DishCore
import Foundation
import Network
import Synchronization

/// The session's handler for the host's datagrams, as the mailbox carries it
/// to the receive queue.
final class DatagramHandlerBox: Sendable {
    let handle: @Sendable (Data) -> Void

    init(_ handle: @escaping @Sendable (Data) -> Void) {
        self.handle = handle
    }
}

/// A connected UDP socket to the host's control port, delivering what the
/// host sends on one queue. The send side counts its datagrams in flight
/// in atomic words, so a report leaves it without a lock; the handler
/// reaches the receive queue through a mailbox, the way a pad's route does.
final class UdpControlTransport: MoonlightControlTransport, Sendable {
    static let readyTimeout: TimeInterval = 5
    /// How long a close waits for the datagrams already handed over before
    /// it cuts the socket anyway.
    static let drainTimeout: TimeInterval = 1
    /// How long a close keeps the socket after the last datagram was
    /// processed: processed means handed to the network stack, not yet on
    /// the wire, and a cancel on its heels can still lose it.
    static let drainGrace: TimeInterval = 0.1

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let handlerMail = Mailbox<DatagramHandlerBox>()
    /// The receive queue's own: the handler it took from the mail.
    private let handler = ReaderHeld<DatagramHandlerBox>()
    private let ready = Mutex<CheckedContinuation<Bool, Never>?>(nil)
    /// Datagrams handed to the socket and not yet processed, whether a close
    /// is waiting on them, and whether its grace has run.
    private let inFlight = AtomicWord()
    private let closing = AtomicBool(false)
    private let graceElapsed = AtomicBool(false)

    init(
        address: String,
        port: UInt16,
        queue: DispatchQueue = ThreadRole.moonlightUdp.queue(label: "dish.moonlight.control-udp", qos: .userInteractive)
    ) {
        self.queue = queue
        connection = NWConnection(host: NWEndpoint.Host(address), port: NWEndpoint.Port(rawValue: port) ?? .any, using: .udp)
    }

    func setOnDatagram(_ handle: @escaping @Sendable (Data) -> Void) {
        handlerMail.post(DatagramHandlerBox(handle))
    }

    /// Opens the socket; false when the path never becomes ready.
    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            ready.withLock { $0 = continuation }
            connection.stateUpdateHandler = { [weak self] state in self?.stateChanged(state) }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + Self.readyTimeout) { [weak self] in self?.settleReady(false) }
        }
    }

    func send(_ datagram: Data) {
        inFlight.fetchAdd(1)
        connection.send(content: datagram, completion: .contentProcessed { [weak self] _ in self?.processed() })
    }

    /// Cuts the socket once every datagram already handed over has been
    /// processed and `drainGrace` has passed, or after `drainTimeout`
    /// whatever is still pending: a TERMINATION or a DISCONNECT cancelled
    /// behind is one the host never hears.
    func close() {
        closing.set(true)
        queue.asyncAfter(deadline: .now() + Self.drainGrace) { [weak self] in
            guard let self else { return }
            graceElapsed.set(true)
            cancelIfDrained()
        }
        queue.asyncAfter(deadline: .now() + Self.drainTimeout) { [weak self] in self?.connection.cancel() }
    }

    private func processed() {
        inFlight.fetchAdd(-1)
        cancelIfDrained()
    }

    private func cancelIfDrained() {
        let drained = closing.get() && graceElapsed.get() && inFlight.load() == 0
        if drained { connection.cancel() }
    }

    private func stateChanged(_ state: NWConnection.State) {
        switch state {
        case .ready:
            settleReady(true)
            receive()
        case .failed, .cancelled, .waiting:
            settleReady(false)
        case .setup, .preparing:
            break
        @unknown default:
            break
        }
    }

    private func settleReady(_ isReady: Bool) {
        let continuation = ready.withLock { waiting -> CheckedContinuation<Bool, Never>? in
            let taken = waiting
            waiting = nil
            return taken
        }
        continuation?.resume(returning: isReady)
    }

    private func receive() {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self, error == nil else { return }
            if let data, !data.isEmpty { deliver(data) }
            receive()
        }
    }

    /// On the receive queue: the newest handler, then the datagram.
    private func deliver(_ data: Data) {
        if let fresh = handlerMail.take() { handler.replace(with: fresh) }
        handler.current?.handle(data)
    }
}

/// The host's media ports pinged every half second from one socket each.
final class MoonlightMediaPinger: Sendable {
    static let intervalMs = 500

    private final class Lane: Sendable {
        let connection: NWConnection

        init(address: String, port: UInt16) {
            connection = NWConnection(host: NWEndpoint.Host(address), port: NWEndpoint.Port(rawValue: port) ?? .any, using: .udp)
        }
    }

    private let lanes: [Lane]
    private let payload: String
    private let queue = DispatchQueue(label: "dish.moonlight.media-ping")
    private let timer = Mutex<(any DispatchSourceTimer)?>(nil)
    private let sequence = AtomicWord()
    private let sent = AtomicCounter()

    /// The lanes the SETUPs named; a port the host did not name gets none.
    init(address: String, videoPort: UInt16?, audioPort: UInt16?, payload: String) {
        lanes = [videoPort, audioPort].compactMap { $0 }.map { Lane(address: address, port: $0) }
        self.payload = payload
    }

    /// Which form the pings take, for the session log.
    var mode: String {
        MoonlightMediaPing.usable(payload) ? "SS_PING" : "legacy PING"
    }

    var pingsSent: Int {
        Int(sent.current())
    }

    /// The first ping goes out at once: the host counts its initial-ping
    /// deadline from its own session start, not from when the control link comes up.
    func start() {
        for lane in lanes {
            lane.connection.start(queue: queue)
            drain(lane)
        }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(Self.intervalMs), leeway: .milliseconds(50))
        source.setEventHandler { [weak self] in self?.ping() }
        timer.withLock { $0 = source }
        source.resume()
    }

    func stop() {
        timer.withLock { source in
            source?.cancel()
            source = nil
        }
        lanes.forEach { $0.connection.cancel() }
    }

    private func ping() {
        let number = UInt32(truncatingIfNeeded: sequence.fetchAdd(1))
        let datagram = MoonlightMediaPing.usable(payload) ? MoonlightMediaPing
            .ssPing(payload: payload, sequence: number) : MoonlightMediaPing.legacy
        for lane in lanes {
            lane.connection.send(content: datagram, completion: .contentProcessed { _ in })
        }
        sent.increment()
    }

    private func drain(_ lane: Lane) {
        lane.connection.receiveMessage { [weak self] _, _, _, error in
            guard let self, error == nil else { return }
            drain(lane)
        }
    }
}
