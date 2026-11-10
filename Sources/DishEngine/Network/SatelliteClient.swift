// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import CryptoKit
import Darwin
import DishCore
import Foundation
import Synchronization

/// The encrypted UDP data plane to one satellite session (contract §Crypto,
/// §Liveness): one raw POSIX socket, the session key and token, counters
/// from 1 per direction, the replay guard, the heartbeat and the receive
/// loop. Streams only; topology rides REST. The key is the HKDF-derived
/// session key: the pairing key never reaches this class.
///
/// Nothing on the send or receive path takes a lock. Every sender holds the
/// send gate from claiming its counter to its `sendto`, so the session's
/// datagrams leave in counter order, and a re-key or a socket change holds
/// it too; the generation it seals under, the target and the fd are words
/// and an object slot replaced only under the gate. The receive loop takes
/// each generation and handler set through a mailbox, and is joined before
/// the fd closes. Every field is an atomic word, a mailbox, a lock or a
/// `let`, so the client is `Sendable` with nothing promised past the
/// compiler, and it is the `PadSink` a bound pad's feed sends to.
package final class SatelliteClient: Sendable {

    static let heartbeatIntervalMs = ProtocolConstants.heartbeatIntervalMs
    static let heartbeatMissMax = ProtocolConstants.heartbeatMissMax
    /// The receive thread's class: the pads' own, so the return paths and
    /// the acks never queue behind lower work.
    static let receiveQualityOfService = QualityOfService.userInteractive

    // MARK: - Under the gate

    let gate = SendGate()
    /// The socket fd, −1 when closed: written under the gate, read by the
    /// senders under it and by the receive loop, which is joined first.
    private let fdWord = AtomicWord(-1)
    /// `SendTarget.packed`, zero while closed; written under the gate.
    private let targetWord = AtomicWord()
    /// The key and token the last session PUT installed: replaced only under
    /// the gate, where a re-key also restarts the counter, so no send pairs
    /// one generation's key with the other's counter.
    private let sendGeneration = ReaderHeld<SessionGeneration>()
    /// The last counter claimed, post-increment from 0 so a generation's
    /// first packet rides counter 1: claimed under the gate, read anywhere
    /// by the re-key poll.
    private let sendCounterWord = AtomicWord()
    /// The settled version, which picks the 0x000C shape.
    private let protocolVersionWord = AtomicWord(Int64(ProtocolConstants.protocolVersionWhenAbsent))
    /// The datagram's way out: `sendto`, or a test's stand-in.
    let sendDatagram: SocketSend

    // MARK: - The receive loop's

    /// Each new generation, for the receive loop.
    let generationMail = Mailbox<SessionGeneration>()
    /// Owned by the receive loop: the generation it opens datagrams under.
    let receiveGeneration = ReaderHeld<SessionGeneration>()
    /// The highest counter successfully opened, so a forged header cannot
    /// advance it; the first packet is exempt while it is zero.
    let lastRecvCounter = AtomicCounter()
    /// Datagrams opened this session, and datagrams refused (a bad header,
    /// another token, a replay, a failed AEAD): Diagnostics reads both.
    let received = AtomicCounter()
    let dropped = AtomicCounter()
    let receiveRunning = AtomicBool(false)
    /// Balances the receive loop, so `closeSocket` can join it (bounded by
    /// the 500 ms receive timeout) before the fd closes.
    let receiveDrained = DispatchGroup()
    private let handlerSet = TrackedLock(ReceiveHandlers(), "satellite.handlers")
    private let handlerMail = Mailbox<ReceiveHandlersBox>()
    /// Owned by the receive loop: the set it calls, refreshed from the mail.
    let receiveHandlers = ReaderHeld<ReceiveHandlersBox>()

    // MARK: - Liveness

    let heartbeatRunning = AtomicBool(false)
    let heartbeatQueue = ThreadRole.heartbeat.queue(label: "dish.satellite.heartbeat", qos: .userInteractive)
    let heartbeatTimer = Mutex<(any DispatchSourceTimer)?>(nil)
    /// Consecutive unacknowledged heartbeats: bumped by the heartbeat,
    /// zeroed by the receive loop.
    let missedAcks = AtomicInt(0)
    /// Read by the connection's alive tick.
    let connectionAlive = AtomicBool(true)
    /// The latest enriched ack packed in one word, zero while none.
    private let heartbeatAckWord = AtomicWord()
    /// The close-notify reason byte, −1 while none; reset by a new generation.
    let sessionCloseReason = AtomicInt(-1)
    /// The heartbeat arms the ping clock and the main actor reads the
    /// window, under the lock; the receive loop only leaves an ack's time.
    private let latency = TrackedLock(LatencyWindow(), "satellite.latency")
    /// An ack's arrival time the window has not paired yet, zero while none.
    private let pendingAckMs = AtomicWord()

    package init(sendDatagram: @escaping SocketSend = systemSend) {
        self.sendDatagram = sendDatagram
    }

    deinit {
        closeSocket()
    }

    // MARK: - Handlers

    /// The return paths' routes, posted whole to the receive loop.
    func setFeedbackRoutes(_ routes: FeedbackRoutes?) {
        updateHandlers { $0.feedback = routes }
    }

    /// Called on the receive loop for an authenticated close-notify; an
    /// unknown future reason byte reads as `.shutdown`.
    func setSessionCloseHandler(_ handler: (@Sendable (CloseReason) -> Void)?) {
        updateHandlers { $0.sessionClose = handler }
    }

    var hasFeedbackRoutes: Bool {
        handlerSet.withLock { $0.feedback != nil }
    }

    private func updateHandlers(_ change: @Sendable (inout ReceiveHandlers) -> Void) {
        let mail = handlerMail
        handlerSet.withLock { handlers in
            change(&handlers)
            mail.post(ReceiveHandlersBox(handlers))
        }
    }

    /// The receive loop's step before a dispatch: one relaxed load while no
    /// handler changed.
    func refreshReceiveHandlers() -> ReceiveHandlers {
        if let fresh = handlerMail.take() { receiveHandlers.replace(with: fresh) }
        return receiveHandlers.current?.handlers ?? ReceiveHandlers()
    }

    // MARK: - Lifecycle

    /// Install a session PUT's material: aim the socket at `host:udpPort`
    /// (kept when unchanged, the re-key path), swap in the token and the
    /// derived key, and restart the counters, the replay guard, liveness, the
    /// ack snapshot, the close latch and the latency window. False, leaving
    /// the client closed, when the socket cannot be aimed there. An endpoint
    /// change stops and joins the loops before the old fd closes; the caller
    /// starts them again.
    @discardableResult
    func setConnectionParams(
        host: String,
        udpPort: UInt16,
        token: UInt32,
        sessionKey: SymmetricKey,
        protocolVersion: Int = ProtocolConstants.protocolVersionWhenAbsent
    ) -> Bool {
        guard let target = SendTarget.resolve(host: host, udpPort: udpPort), ensureSocket(target) else { return false }
        let fresh = SessionGeneration(key: sessionKey, token: token)
        gate.hold {
            sendGeneration.replace(with: fresh)
            sendCounterWord.store(0)
        }
        protocolVersionWord.store(Int64(protocolVersion))
        generationMail.post(fresh)
        lastRecvCounter.set(0)
        received.reset()
        dropped.reset()
        missedAcks.set(0)
        connectionAlive.set(true)
        heartbeatAckWord.store(0)
        sessionCloseReason.set(-1)
        let pending = pendingAckMs
        latency.withLock { window in
            pending.store(0)
            window.reset()
        }
        return true
    }

    func closeSocket() {
        stopHeartbeat()
        stopReceiveLoop()
        let retired = gate.hold { () -> Int32 in
            targetWord.store(0)
            return Int32(truncatingIfNeeded: fdWord.exchange(-1))
        }
        if retired >= 0 { close(retired) }
    }

    /// Open, or keep, the socket aimed at `target`: DSCP EF, no SIGPIPE and a
    /// 500 ms receive timeout, as the sibling clients set them.
    private func ensureSocket(_ target: SendTarget) -> Bool {
        let (alreadyAimed, replacing) = gate.hold { () -> (Bool, Bool) in
            let open = fdWord.load() >= 0
            let same = open && SendTarget(packed: targetWord.load()) == target
            return (same, open && !same)
        }
        if alreadyAimed { return true }
        guard let fd = openSocket() else { return false }
        if replacing { closeSocket() }
        let stale = gate.hold { () -> Int32 in
            targetWord.store(target.packed)
            return Int32(truncatingIfNeeded: fdWord.exchange(Int64(fd)))
        }
        if stale >= 0 { close(stale) }
        return true
    }

    /// Whether the socket is open; a sender checks again under the gate.
    var isOpen: Bool {
        fdWord.load() >= 0
    }

    /// The fd the receive loop reads, which `closeSocket` joins before the
    /// fd closes.
    var receiveFd: Int32 {
        Int32(truncatingIfNeeded: fdWord.load())
    }

    /// The caller holds the gate: the fd, or −1, and where it sends.
    func sendTarget() -> (fd: Int32, target: SendTarget?) {
        (Int32(truncatingIfNeeded: fdWord.load()), SendTarget(packed: targetWord.load()))
    }

    /// The caller holds the gate: the next counter, with the generation it
    /// seals under; nil before the first session PUT.
    func claimSend() -> (generation: SessionGeneration, sequence: UInt64)? {
        guard let generation = sendGeneration.current else { return nil }
        return (generation, UInt64(bitPattern: sendCounterWord.fetchAddRelaxed(1)) &+ 1)
    }

    /// One packet's token and sequence drawn in one gate hold, as a send
    /// draws them: the seal never mixes generations with a concurrent
    /// re-key. Nil before the first session PUT.
    func nextSendMaterial() -> (token: UInt32, sequence: UInt64)? {
        gate.hold { claimSend().map { ($0.generation.token, $0.sequence) } }
    }

    // MARK: - Snapshots for the alive tick

    /// The latest enriched heartbeat ack, nil before the first this session.
    func heartbeatAckSnapshot() -> HeartbeatAck? {
        HeartbeatAck(packed: heartbeatAckWord.load())
    }

    func storeHeartbeatAck(_ ack: HeartbeatAck) {
        heartbeatAckWord.store(ack.packed)
    }

    /// The last counter used, clamped: past exhaustion the re-key poll keeps
    /// reading "re-PUT needed", never wraps back under the threshold.
    var sendCounter: UInt32 {
        UInt32(clamping: UInt64(bitPattern: sendCounterWord.load()))
    }

    /// Places the send counter under the gate: production only restarts it;
    /// tests place it near a threshold without billions of sends.
    func placeSendCounter(_ value: UInt64) {
        gate.hold { sendCounterWord.store(Int64(bitPattern: value)) }
    }

    var settledProtocolVersion: Int {
        Int(protocolVersionWord.loadRelaxed())
    }

    /// The median heartbeat round trip halved and the samples behind it; nil
    /// until the first paired ack.
    func latencySnapshot() -> (p50OneWayMs: Double?, samples: Int) {
        let pending = pendingAckMs
        return latency.withLock { window in
            pairPendingAck(pending, into: &window)
            return (window.p50OneWayMs(), window.sampleCount)
        }
    }

    /// The round trips the Diagnostics page shows beside the one-way figure.
    func latencySummary() -> LatencySummary {
        let pending = pendingAckMs
        return latency.withLock { window in
            pairPendingAck(pending, into: &window)
            return window.summary()
        }
    }

    /// Stamp the single-in-flight ping clock; the loss reclaim and the
    /// never-overwrite rule live in `LatencyWindow`.
    func armLatencyPing(nowMs: Int64) {
        let pending = pendingAckMs
        latency.withLock { window in
            pairPendingAck(pending, into: &window)
            window.armPing(nowMs: nowMs)
        }
    }

    /// An arriving ack, on the receive loop: its time waits for the next
    /// holder of the window. An ack already waiting keeps its time, and this
    /// one finds its ping consumed, as the window decides.
    func recordLatencyAck(nowMs: Int64) {
        // A refused exchange is an ack already waiting, which keeps its time.
        _ = pendingAckMs.compareExchange(expected: 0, desired: max(nowMs, 1))
    }

    /// Monotonic milliseconds for the latency clock, never 0 in practice, so
    /// the window's 0 sentinel stays free.
    static func monotonicNowMs() -> Int64 {
        Int64(clock_gettime_nsec_np(CLOCK_UPTIME_RAW) / 1_000_000)
    }
}

/// Pairs the ack the receive loop left, if any; the caller holds the window's lock.
private func pairPendingAck(_ pending: AtomicWord, into window: inout LatencyWindow) {
    let ackMs = pending.exchange(0)
    if ackMs != 0 { window.ackReceived(nowMs: ackMs) }
}

/// A UDP socket with DSCP EF, no SIGPIPE and a 500 ms receive timeout; nil
/// when the system refuses one.
private func openSocket() -> Int32? {
    let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard fd >= 0 else { return nil }
    var tos: Int32 = dscpExpeditedForwarding
    var one: Int32 = 1
    var timeout = timeval(tv_sec: 0, tv_usec: receiveTimeoutUs)
    let intSize = socklen_t(MemoryLayout<Int32>.size)
    // Best-effort, as on the sibling clients: a Wi-Fi driver may strip the
    // TOS byte without failing the call, and the receive timeout only paces
    // the loop's checks.
    _ = setsockopt(fd, IPPROTO_IP, IP_TOS, &tos, intSize)
    _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, intSize)
    _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    return fd
}

/// DSCP EF (Expedited Forwarding), every client's `IP_TOS`.
let dscpExpeditedForwarding: Int32 = 0xB8

private let receiveTimeoutUs: Int32 = 500_000
