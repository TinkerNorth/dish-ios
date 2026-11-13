// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Settings › Setup & help › Diagnostics: dish-mac's words for an iPhone.
extension L10n {

    // MARK: - The page

    var diagnostics: String {
        catalog.text("Diagnostics")
    }

    var diagnosticsDetail: String {
        catalog.text("Each host’s session, each controller down to the wire, and a log of what changed.")
    }

    var events: String {
        catalog.text("Events")
    }

    var eventsNote: String {
        catalog.text("Newest first. The log covers this run of Dish and is not saved.")
    }

    var noEventsYet: String {
        catalog.text("No events yet.")
    }

    var noPCsForDiagnostics: String {
        catalog.text("No PCs yet. Pair one on the Connections tab and its session shows here.")
    }

    var noControllersConnected: String {
        catalog.text("No controllers connected")
    }

    var copy: String {
        catalog.text("Copy")
    }

    var copied: String {
        catalog.text("Copied")
    }

    var lockStatistics: String {
        catalog.text("Lock statistics")
    }

    // MARK: - The app's lines

    var appVersion: String {
        catalog.text("App version")
    }

    var protocolKey: String {
        catalog.text("Protocol")
    }

    /// The short form beside the Protocol label: v3.
    func protocolTag(_ version: Int) -> String {
        catalog.format("v%lld", version)
    }

    func protocolOffered(_ settled: String, _ offered: Int) -> String {
        catalog.format("%@ (offered v%lld)", settled, offered)
    }

    var satelliteUpdateRecommended: String {
        catalog.text("Satellite update recommended")
    }

    var localNetwork: String {
        catalog.text("Local Network")
    }

    var localNetworkAllowed: String {
        catalog.text("Allowed")
    }

    var localNetworkDenied: String {
        catalog.text("Denied")
    }

    var localNetworkNotAsked: String {
        catalog.text("Not asked yet")
    }

    // MARK: - A PC's lines

    var address: String {
        catalog.text("Address")
    }

    var linkTier: String {
        catalog.text("Link tier")
    }

    var tierBasic: String {
        catalog.text("Basic")
    }

    var session: String {
        catalog.text("Session")
    }

    var noSessionRightNow: String {
        catalog.text("No session right now")
    }

    // MARK: - A Moonlight host's card

    var sessionIdle: String {
        catalog.text("Idle")
    }

    var sessionLaunching: String {
        catalog.text("Launching")
    }

    var sessionLive: String {
        catalog.text("Live")
    }

    var sessionEnded: String {
        catalog.text("Ended")
    }

    var hostName: String {
        catalog.text("Host name")
    }

    var hostApp: String {
        catalog.text("Host app")
    }

    var gfeVersion: String {
        catalog.text("GFE version")
    }

    var runningApp: String {
        catalog.text("Running app")
    }

    var controlRoundTrip: String {
        catalog.text("Control round trip")
    }

    func padNumber(_ number: Int) -> String {
        catalog.format("Pad %lld", number)
    }

    var epoch: String {
        catalog.text("Epoch")
    }

    func epochApplied(_ applied: Int) -> String {
        catalog.format("applied: %lld", applied)
    }

    func epochOnHostAndApplied(_ host: Int, _ applied: Int) -> String {
        catalog.format("on the host: %lld · applied: %lld", host, applied)
    }

    var inStep: String {
        catalog.text("in step")
    }

    var outOfStep: String {
        catalog.text("out of step")
    }

    var waitingForTheFirstHeartbeat: String {
        catalog.text("waiting for the first heartbeat")
    }

    func controllersConfirmed(_ confirmed: String) -> String {
        catalog.format("confirmed: %@", confirmed)
    }

    func controllersOnHostAndConfirmed(_ host: String, _ confirmed: String) -> String {
        catalog.format("on the host: %@ · confirmed: %@", host, confirmed)
    }

    var none: String {
        catalog.text("none")
    }

    var virtualControllers: String {
        catalog.text("Virtual controllers")
    }

    var available: String {
        catalog.text("available")
    }

    var unavailable: String {
        catalog.text("unavailable")
    }

    var unknown: String {
        catalog.text("unknown")
    }

    func inUse(_ count: Int) -> String {
        catalog.format("%lld in use", count)
    }

    var roundTrip: String {
        catalog.text("Round trip")
    }

    var noSamplesYet: String {
        catalog.text("no samples yet")
    }

    func roundTripFigures(_ p50: String, _ p99: String, _ oneWay: String) -> String {
        catalog.format("%@ p50 · %@ p99 · %@ one way", p50, p99, oneWay)
    }

    func pingsOf(_ samples: Int, _ capacity: Int) -> String {
        catalog.format("%lld of %lld pings", samples, capacity)
    }

    var missedHeartbeats: String {
        catalog.text("Missed heartbeats")
    }

    var sent: String {
        catalog.text("Sent")
    }

    var received: String {
        catalog.text("Received")
    }

    var dropped: String {
        catalog.text("Dropped")
    }

    var replayGuard: String {
        catalog.text("Replay guard")
    }

    var ready: String {
        catalog.text("Ready")
    }

    var connecting: String {
        catalog.text("Connecting…")
    }

    // MARK: - A controller's lines

    var connection: String {
        catalog.text("Connection")
    }

    var inputRate: String {
        catalog.text("Input rate")
    }

    var motionRate: String {
        catalog.text("Motion rate")
    }

    func hertz(_ hz: Int) -> String {
        catalog.format("%lld Hz", hz)
    }

    func reportsCount(_ count: Int) -> String {
        catalog.format("%lld reports", count)
    }

    var type: String {
        catalog.text("Type")
    }

    var onTheWire: String {
        catalog.text("On the wire")
    }

    var notDeclaredToTheHostYet: String {
        catalog.text("Not declared to the host yet")
    }

    var controllerIndex: String {
        catalog.text("Controller index")
    }

    var confirmedByHost: String {
        catalog.text("Confirmed by host")
    }

    var yes: String {
        catalog.text("yes")
    }

    var no: String {
        catalog.text("no")
    }

    var advertised: String {
        catalog.text("Advertised")
    }

    var nothing: String {
        catalog.text("nothing")
    }

    var touchpadOnTheWire: String {
        catalog.text("Touchpad on the wire")
    }

    var padWord: String {
        catalog.text("pad")
    }

    var mouseWord: String {
        catalog.text("mouse")
    }

    var offWord: String {
        catalog.text("off")
    }

    var analogTriggers: String {
        catalog.text("Analog triggers")
    }

    var microphone: String {
        catalog.text("Microphone")
    }

    var hapticAudio: String {
        catalog.text("Haptic audio")
    }

    var extraButtons: String {
        catalog.text("Extra buttons")
    }

    // MARK: - The lock statistics

    func lockCounts(_ acquisitions: Int, _ contended: Int) -> String {
        catalog.format("%lld taken · %lld contended", acquisitions, contended)
    }

    var roleInput: String {
        catalog.text("Input")
    }

    var roleReceive: String {
        catalog.text("Receive")
    }

    var roleHeartbeat: String {
        catalog.text("Heartbeat")
    }

    var roleFeedback: String {
        catalog.text("Feedback")
    }

    var roleMain: String {
        catalog.text("Main")
    }

    var roleOther: String {
        catalog.text("Other")
    }

    /// The Moonlight control socket's queue.
    var roleMoonlightControl: String {
        catalog.text("Moonlight control")
    }

    // MARK: - The events

    func eventLinkAppeared(_ subject: String, _ state: String) -> String {
        catalog.format("%@: appeared, %@", subject, state)
    }

    func eventLinkChanged(_ subject: String, _ from: String, _ to: String) -> String {
        catalog.format("%@: %@ → %@", subject, from, to)
    }

    func eventLinkRemoved(_ subject: String) -> String {
        catalog.format("%@: removed", subject)
    }

    func eventPadAttached(_ subject: String) -> String {
        catalog.format("%@: attached", subject)
    }

    func eventPadDetached(_ subject: String) -> String {
        catalog.format("%@: detached", subject)
    }

    func eventPadBound(_ subject: String, _ host: String) -> String {
        catalog.format("%@: bound to %@", subject, host)
    }

    func eventPadUnbound(_ subject: String, _ host: String) -> String {
        catalog.format("%@: unbound from %@", subject, host)
    }
}
