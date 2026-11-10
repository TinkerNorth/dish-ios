// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Darwin
import DishCore
import Foundation

/// The socket shell: seal and `sendto`, the heartbeat timer and the receive
/// loop. Framing and the AEAD are `PacketCodec` and `SessionCrypto`.
extension SatelliteClient {

    // MARK: - Seal and send

    /// Seal one inner frame and send it, on the caller's thread:
    /// `token(4 BE) | counter(4 BE) | ChaCha20-Poly1305(msgType | msgLen | payload)`.
    /// `encode` writes every one of the `payloadCount` bytes into a stack
    /// buffer that already holds the inner header, so CryptoKit's sealed box
    /// is the send's only allocation. Non-blocking: a full socket buffer
    /// drops the datagram rather than stalling the pad's queue, and every
    /// stream is loss-safe.
    func sendEncrypted(msgType: UInt16, payloadCount: Int, encode: (UnsafeMutableRawBufferPointer) -> Void) {
        let innerCount = ProtocolConstants.innerHeaderSize + payloadCount
        let datagramCount = ProtocolConstants.headerSize + innerCount + ProtocolConstants.authTagSize
        guard isOpen, datagramCount <= ProtocolConstants.udpDatagramMaxBytes else { return }
        withUnsafeTemporaryAllocation(byteCount: ProtocolConstants.udpDatagramMaxBytes, alignment: 16) { scratch in
            let datagram = UnsafeMutableRawBufferPointer(rebasing: scratch[..<datagramCount])
            let inner = UnsafeMutableRawBufferPointer(
                rebasing: datagram[ProtocolConstants.headerSize ..< ProtocolConstants.headerSize + innerCount]
            )
            PacketCodec.writeInnerHeader(msgType: msgType, payloadCount: payloadCount, into: inner)
            encode(UnsafeMutableRawBufferPointer(rebasing: inner[ProtocolConstants.innerHeaderSize...]))
            gate.hold { sealAndSend(datagram, innerCount: innerCount) }
        }
    }

    /// The caller holds the gate, from the counter's claim to the `sendto`.
    /// A counter never wraps: past 2^32 − 1 the session goes silent, and the
    /// proactive re-key fires 268M packets before that.
    private func sealAndSend(_ datagram: UnsafeMutableRawBufferPointer, innerCount: Int) {
        let (fd, target) = sendTarget()
        guard fd >= 0, let target, let claim = claimSend(), claim.sequence <= UInt64(UInt32.max) else { return }
        let counter = UInt32(claim.sequence)
        let generation = claim.generation
        let box = UnsafeMutableRawBufferPointer(rebasing: datagram[ProtocolConstants.headerSize...])
        guard let sealed = try? SessionCrypto.seal(
            UnsafeRawBufferPointer(rebasing: box[..<innerCount]),
            into: box,
            key: generation.key,
            direction: .up,
            counter: counter,
            token: generation.token
        ) else { return }
        PacketCodec.writeHeader(token: generation.token, counter: counter, into: datagram)
        var address = target.sockaddr
        blockingRegion("satellite.sendto")
        // A refused send is a dropped datagram: every stream is loss-safe.
        _ = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { destination in
                sendDatagram(
                    fd,
                    UnsafeRawPointer(datagram.baseAddress),
                    ProtocolConstants.headerSize + sealed,
                    MSG_DONTWAIT,
                    destination,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
    }

    // MARK: - Heartbeat

    /// The 2 s heartbeat (contract §Liveness); the first beat fires at once,
    /// so a fresh session proves the data path without waiting an interval.
    func startHeartbeat() {
        guard !heartbeatRunning.getAndSet(true) else { return }
        missedAcks.set(0)
        connectionAlive.set(true)
        let queue = heartbeatQueue
        let interval = Self.heartbeatIntervalMs
        heartbeatTimer.withLock { slot in
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(interval), leeway: .milliseconds(heartbeatLeewayMs))
            timer.setEventHandler { [weak self] in self?.heartbeatTick() }
            timer.resume()
            slot = timer
        }
    }

    func stopHeartbeat() {
        heartbeatRunning.set(false)
        heartbeatTimer.withLock { slot in
            slot?.cancel()
            slot = nil
        }
    }

    /// The ping clock starts on this beat's own stamp; an in-flight ping
    /// keeps its clock, as `LatencyWindow` decides.
    private func heartbeatTick() {
        guard heartbeatRunning.get() else { return }
        sendEncrypted(msgType: ProtocolConstants.msgHeartbeat, payloadCount: 0) { _ in }
        armLatencyPing(nowMs: Self.monotonicNowMs())
        if missedAcks.incrementAndGet() >= Self.heartbeatMissMax {
            connectionAlive.set(false)
        }
    }

    // MARK: - Receive loop

    /// The loop runs on a thread of its own at the pad's quality of service,
    /// with one datagram buffer on that thread's stack for its whole life.
    func startReceiveLoop() {
        guard !receiveRunning.getAndSet(true) else { return }
        receiveDrained.enter()
        let drained = receiveDrained
        let thread = Thread { [weak self] in
            ThreadRole.receive.enterThread()
            withUnsafeTemporaryAllocation(byteCount: ProtocolConstants.udpDatagramMaxBytes, alignment: 16) { buffer in
                while let client = self, client.receiveRunning.get() {
                    client.receiveOne(into: buffer)
                }
            }
            drained.leave()
        }
        thread.name = "dish.satellite.receive"
        thread.qualityOfService = Self.receiveQualityOfService
        thread.start()
    }

    /// Stop the loop and join it, bounded by the receive timeout, so the fd
    /// can close without racing a blocked `recvfrom` onto a reused fd.
    func stopReceiveLoop() {
        guard receiveRunning.getAndSet(false) else { return }
        blockingRegion("satellite.receiveJoin")
        // The loop leaves within one receive timeout; a wait that outlasts
        // the bound closes the fd anyway, as dish-mac's does.
        _ = receiveDrained.wait(timeout: .now() + receiveJoinSeconds)
    }

    /// One datagram into the loop's buffer, at the contract's ceiling: a
    /// shorter buffer would truncate a full-size frame and fail its AEAD.
    private func receiveOne(into buffer: UnsafeMutableRawBufferPointer) {
        let fd = receiveFd
        guard fd >= 0 else { return }
        blockingRegion("satellite.recvfrom")
        let bytesRead = recv(fd, buffer.baseAddress, buffer.count, 0)
        // Zero or less is the receive timeout's tick or a transient error:
        // the loop goes round and checks whether it still runs.
        guard bytesRead > 0 else { return }
        processIncoming(UnsafeRawBufferPointer(rebasing: buffer[..<bytesRead]))
    }

    /// One whole datagram handed in as `Data`, as the tests hand them.
    func processIncoming(_ datagram: Data) {
        datagram.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in processIncoming(raw) }
    }

    /// One datagram where it lies: the header read in place, the token
    /// filter, the replay guard, the AEAD opened in place and bound to the
    /// direction, counter and token, then the dispatch on a slice of the
    /// plaintext. Every failure is a silent drop, as on the sibling clients.
    func processIncoming(_ datagram: UnsafeRawBufferPointer) {
        guard let header = PacketCodec.parseHeader(datagram) else { return }
        if let fresh = generationMail.take() {
            receiveGeneration.replace(with: fresh)
            lastRecvCounter.set(0)
        }
        guard let session = receiveGeneration.current, header.token == session.token else { return }
        let lastRecv = UInt32(truncatingIfNeeded: lastRecvCounter.current())
        let replayed = lastRecv != 0 && header.counter <= lastRecv
        guard !replayed, let plain = try? SessionCrypto.open(
            boxBytes: UnsafeRawBufferPointer(rebasing: datagram[ProtocolConstants.headerSize...]),
            key: session.key,
            direction: .down,
            counter: header.counter,
            token: session.token
        ) else { return }
        lastRecvCounter.set(UInt64(header.counter))
        guard let inner = PacketCodec.parseInnerInPlace(plain) else { return }
        dispatch(inner)
    }

    /// One opened message, on the receive loop; the return paths post to the
    /// pads' feedback in one hop.
    private func dispatch(_ inner: PacketCodec.InnerMessage) {
        let handlers = refreshReceiveHandlers()
        switch inner.msgType {
        case ProtocolConstants.msgHeartbeatAck: acknowledge(inner.payload)
        case ProtocolConstants.msgRumble: route(rumble: inner.payload, through: handlers.feedback)
        case ProtocolConstants.msgLightbar: route(lightbar: inner.payload, through: handlers.feedback)
        case ProtocolConstants.msgTriggerEffects: route(triggerEffects: inner.payload, through: handlers.feedback)
        case ProtocolConstants.msgPlayerLeds: route(playerLeds: inner.payload, through: handlers.feedback)
        case ProtocolConstants.msgSessionClose: close(inner.payload, relay: handlers.sessionClose)
        default: break
        }
    }

    /// The ack pairs with the in-flight ping before the liveness flags flip,
    /// so the round-trip window and the alive tick agree on order. A short,
    /// pre-protocol-1 ack counts for liveness and not for reconcile.
    private func acknowledge(_ payload: Data) {
        recordLatencyAck(nowMs: Self.monotonicNowMs())
        missedAcks.set(0)
        connectionAlive.set(true)
        if let ack = HeartbeatAck.parse(payload) {
            storeHeartbeatAck(ack)
        }
    }

    private func route(rumble payload: Data, through routes: FeedbackRoutes?) {
        guard let command = RumbleCommand.parse(payload) else { return }
        routes?.rumble(
            controllerIndex: command.controllerIndex,
            strong: command.strongMagnitude,
            weak: command.weakMagnitude,
            durationMs: command.durationMs
        )
    }

    private func route(lightbar payload: Data, through routes: FeedbackRoutes?) {
        guard let command = LightbarCommand.parse(payload) else { return }
        routes?.lightbar(controllerIndex: command.controllerIndex, red: command.r, green: command.g, blue: command.b)
    }

    private func route(triggerEffects payload: Data, through routes: FeedbackRoutes?) {
        guard let command = TriggerEffectsCommand.parse(payload) else { return }
        routes?.triggerEffects(controllerIndex: command.controllerIndex, left: command.left, right: command.right)
    }

    private func route(playerLeds payload: Data, through routes: FeedbackRoutes?) {
        guard let command = PlayerLedsCommand.parse(payload) else { return }
        routes?.playerLeds(controllerIndex: command.controllerIndex, player: command.playerNumber)
    }

    /// The reason latches and the session reads dead now: it is already gone
    /// on the satellite, so the alive tick need not wait out the heartbeat.
    private func close(_ payload: Data, relay: (@Sendable (CloseReason) -> Void)?) {
        guard let byte = payload.first else { return }
        sessionCloseReason.set(Int(byte))
        connectionAlive.set(false)
        relay?(CloseReason(rawValue: byte) ?? .shutdown)
    }
}

private let heartbeatLeewayMs = 100
private let receiveJoinSeconds = 1.0
