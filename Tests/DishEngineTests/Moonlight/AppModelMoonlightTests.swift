// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The composition root's Moonlight half: a binding to a host becomes the
/// pad its session is asked to carry, the pad's feed routes to the host's
/// link, the PIN prompt follows the pairing, and the intents reach the manager.
@MainActor
final class AppModelMoonlightTests: XCTestCase {

    private var gateway: ScriptedMoonlightGateway!
    private var edges: FakeMoonlightEdges!
    private var moonlight: MoonlightConnectionManager!
    private var source: FakeControllerSource!
    private var model: AppModel!
    private let host = MoonlightHost(name: "PC", address: "10.0.0.5", uniqueId: "abc")
    private let dualSense = ControllerSlot(
        id: "ds",
        name: "DualSense",
        capabilities: ControllerCapabilities(hasMotion: true, hasTouchpad: true, hasRumble: true, hasLightbar: true, hasBattery: true),
        family: .dualSense
    )

    override func setUp() async throws {
        try await super.setUp()
        let defaults = try TestDefaults.fresh(self)
        gateway = ScriptedMoonlightGateway()
        gateway.answerPlain("/serverinfo", .init(status: 200, body: MoonlightManagerTestCase.pairedInfo))
        gateway.answerSecure("/serverinfo", .init(status: 200, body: MoonlightManagerTestCase.pairedInfo))
        gateway.answerSecure("/applist", .init(status: 200, body: MoonlightManagerTestCase.appList))
        gateway.answerSecure("/launch", .init(status: 200, body: MoonlightManagerTestCase.launchOk))
        gateway.answerSecure("/cancel", .init(status: 200, body: MoonlightManagerTestCase.cancelled))
        edges = FakeMoonlightEdges()
        moonlight = MoonlightConnectionManager(
            store: MoonlightHostStore(defaults: defaults),
            gateway: gateway,
            identity: nil,
            edges: edges,
            discover: { [] }
        )
        var record = RememberedMoonlightHost(host: host, paired: true)
        record.uniqueId = "abc"
        moonlight.store.put(record)
        moonlight.publishRemembered()
        source = FakeControllerSource(slots: [dualSense])
        model = AppModel(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: ManualTicker(), now: Date.init),
            localNetwork: RecordedLocalNetworkAccess(),
            pads: ControllerStack(source: source, defaults: defaults),
            network: TestNetwork.stack(defaults: defaults, moonlight: moonlight),
            tips: RecordedTipStore(shelf: .success([])),
            motionSensor: FakeMotionSensor(),
            resendTicker: ManualTicker()
        )
    }

    override func tearDown() async throws {
        moonlight?.applyDesired([:])
        await moonlight?.awaitQuiet()
        model = nil
        try await super.tearDown()
    }

    private func waitUntil(_ predicate: @escaping @MainActor () -> Bool) async -> Bool {
        for _ in 0 ..< 200 where !predicate() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return predicate()
    }

    func testABindingBecomesThePadTheHostIsAskedToCarryAndTheSlotRoutesToItsLink() async throws {
        model.bind(slotId: "ds", to: host.id)
        XCTAssertEqual(model.bindingProgress, .done, "a Moonlight binding is durable intent, done at once")
        XCTAssertEqual(moonlight.desired[host.id]?.map(\.slotId), ["ds"])
        XCTAssertEqual(moonlight.desired[host.id]?.first?.announced.type, MoonlightControllerType.playStation, "Auto with motion")
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.pads.map(\.slotId), ["ds"], "the pad is claimed whatever the host answered")
        XCTAssertEqual(moonlight.get(host.id)?.phase, .streaming)
        XCTAssertEqual(model.network.hub.summary(host.id)?.boundSlotIds, ["ds"])
        XCTAssertEqual(model.moonlightFacts.hosts.map(\.id), [host.id])
        XCTAssertEqual(model.moonlightFacts.phases[host.id], .streaming)
        XCTAssertNil(model.pads.types.typeFor("ds"), "the family's own pick is no pick")
        let live = try XCTUnwrap(edges.liveSessions.last)
        _ = live.take()
        source.processor.feed(for: "ds").publish(GamepadReport(buttons: 0x0010))
        XCTAssertEqual(
            live.take(),
            [.state(MoonlightInput.PadFrame(controller: 0, activeMask: 0b0001, buttons: 0x0010))],
            "the pad's feed routes to the host's link"
        )
        model.setControllerFeature(slotId: "ds", .motion, enabled: false)
        XCTAssertEqual(moonlight.desired[host.id]?.first?.announced.type, MoonlightControllerType.xbox, "the switch re-resolves the pad")
        model.setEmulatedType(slotId: "ds", .switchPro)
        XCTAssertEqual(moonlight.desired[host.id]?.first?.announced.type, MoonlightControllerType.nintendo)
        XCTAssertEqual(moonlight.rememberedBindings.first?.controllerType, Int(MoonlightControllerType.nintendo), "kept with the binding")
        XCTAssertEqual(model.pads.types.typeFor("ds"), .switchPro)
        model.unbind(slotId: "ds")
        XCTAssertEqual(moonlight.desired, [:])
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.padCount, 0)
        XCTAssertEqual(moonlight.rememberedBindings, [], "an unbound pad's binding is forgotten")
    }

    func testThePickOfAPadOnAHostReachesTheHostsDesireAndTheFactAndLeavesThePadsOwnPickAlone() async {
        XCTAssertNil(model.shellFacts.controllers.first?.hostEmulation, "unbound")
        model.bind(slotId: "ds", to: host.id)
        XCTAssertEqual(
            model.shellFacts.controllers.first?.hostEmulation,
            HostEmulationFact(type: Int(MoonlightControllerType.auto), isOverride: false)
        )
        model.setMoonlightEmulatedType(slotId: "ds", Int(MoonlightControllerType.nintendo))
        XCTAssertEqual(moonlight.desired[host.id]?.first?.announced.type, MoonlightControllerType.nintendo)
        XCTAssertEqual(
            model.shellFacts.controllers.first?.hostEmulation,
            HostEmulationFact(type: Int(MoonlightControllerType.nintendo), isOverride: true)
        )
        XCTAssertNil(model.pads.types.typeFor("ds"), "the pad's own pick is for the satellites")
        model.setMoonlightEmulatedType(slotId: "ds", Int(MoonlightControllerType.xbox))
        XCTAssertEqual(moonlight.desired[host.id]?.first?.announced.type, MoonlightControllerType.xbox)
        model.setMoonlightEmulatedType(slotId: "ds", nil)
        XCTAssertEqual(moonlight.desired[host.id]?.first?.announced.type, MoonlightControllerType.playStation, "Auto with motion")
        XCTAssertEqual(model.shellFacts.controllers.first?.hostEmulation?.isOverride, false)
        model.unbind(slotId: "ds")
        XCTAssertNil(model.shellFacts.controllers.first?.hostEmulation)
        await moonlight.awaitQuiet()
    }

    func testThePinPromptFollowsThePairingAndTheIntentsReachTheManager() async {
        moonlight.emit(.pairingPinReady(host: host, pin: "0451"))
        XCTAssertEqual(model.moonlightPin, MoonlightPinPrompt(host: host, pin: "0451"))
        XCTAssertEqual(model.moonlightPin?.id, host.id)
        XCTAssertEqual(model.lastMoonlightEvent, .pairingPinReady(host: host, pin: "0451"))
        XCTAssertEqual(model.moonlightFacts.pin, MoonlightPinPrompt(host: host, pin: "0451"), "the page draws the card from its facts")
        XCTAssertEqual(model.moonlightFacts.lastEvent, .pairingPinReady(host: host, pin: "0451"))
        moonlight.emit(.paired(host))
        XCTAssertNil(model.moonlightPin)
        moonlight.emit(.pairingPinReady(host: host, pin: "0452"))
        model.cancelMoonlightPairing(host.id)
        XCTAssertNil(model.moonlightPin)
        XCTAssertEqual(moonlight.pairingGenerations[host.id], 1)
        moonlight.emit(.pairingPinReady(host: host, pin: "0453"))
        moonlight.emit(.pairingFailed(
            host: host,
            reason: MoonlightPairingFailure(phase: 1, kind: .noCertificate, httpStatus: 0, hostSaid: "")
        ))
        XCTAssertNil(model.moonlightPin)
        moonlight.emit(.pairingPinReady(host: host, pin: "0454"))
        model.leftMoonlightHosts()
        XCTAssertNil(model.moonlightPin, "leaving the page ends the pairing its card waits on")
        XCTAssertNil(model.lastMoonlightEvent)
        XCTAssertEqual(moonlight.pairingGenerations[host.id], 2)
        model.setMoonlightApp(host.id, appId: "7", appName: "Steam")
        XCTAssertEqual(moonlight.rememberedAppId(hostId: host.id), "7")
        XCTAssertEqual(model.moonlightFacts.pickedApps[host.id], "7")
        model.forgetMoonlightHost(host.id)
        await moonlight.awaitQuiet()
        XCTAssertNil(moonlight.store.host(id: host.id))
        XCTAssertEqual(model.network.hub.connections, [])
    }

    func testTheOnScreenGamepadBoundToAHostIsAPadTheHostCarries() async throws {
        model.openGamepad()
        model.bind(slotId: onScreenSlotId, to: host.id)
        XCTAssertEqual(model.bindingProgress, .done)
        XCTAssertEqual(moonlight.desired[host.id]?.map(\.slotId), [onScreenSlotId], "the host is asked to carry the on-screen gamepad")
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.pads.map(\.slotId), [onScreenSlotId])
        let live = try XCTUnwrap(edges.liveSessions.last)
        _ = live.take()
        source.processor.feed(for: onScreenSlotId).publish(GamepadReport(buttons: 0x0010))
        XCTAssertEqual(
            live.take(),
            [.state(MoonlightInput.PadFrame(controller: 0, activeMask: 0b0001, buttons: 0x0010))],
            "the on-screen gamepad's feed reaches the host's link"
        )
    }

    func testForgettingAHostUnbindsItsSlotsFirst() async {
        model.bind(slotId: "ds", to: host.id)
        model.forgetMoonlightHost(host.id)
        XCTAssertEqual(model.network.hub.bindings, [:])
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.desired, [:])
        XCTAssertNil(moonlight.get(host.id))
    }

    func testAScanAnAddedAddressAndADisconnectReachTheManager() async {
        model.scanMoonlightHosts()
        XCTAssertTrue(moonlight.isScanning)
        XCTAssertTrue(model.moonlightFacts.scanning)
        XCTAssertFalse(model.addMoonlightHost("   "), "nothing typed")
        gateway.answerPlain("/serverinfo", .unreachable)
        XCTAssertTrue(model.addMoonlightHost(" 10.0.0.9 "))
        let told = await waitUntil { [weak self] in self?.model.lastMoonlightEvent == .noHostAnswered(address: "10.0.0.9") }
        XCTAssertTrue(told, "an address nothing answers is told as an event")
        model.disconnectMoonlightHost(host.id)
        await moonlight.awaitQuiet()
        XCTAssertNil(moonlight.get(host.id), "a host with no session has nothing to stop")
    }

    func testThePagesPickIsRecordedWithTheTitleTheHostListed() async {
        gateway.answerSecure("/applist", .init(status: 200, body: MoonlightManagerTestCase.twoApps))
        model.bind(slotId: "ds", to: host.id)
        await moonlight.awaitQuiet()
        XCTAssertEqual(model.moonlightFacts.apps[host.id]?.map(\.title), ["Desktop", "Steam"], "the session's probe listed the apps")
        model.pickMoonlightApp(host.id, appId: "2")
        XCTAssertEqual(moonlight.rememberedAppId(hostId: host.id), "2")
        XCTAssertEqual(moonlight.rememberedAppName(hostId: host.id), "Steam")
        XCTAssertEqual(model.moonlightFacts.pickedApps[host.id], "2")
        model.pickMoonlightApp(host.id, appId: "")
        XCTAssertEqual(moonlight.rememberedAppId(hostId: host.id), "", "Auto: the first app the host lists")
        XCTAssertEqual(moonlight.rememberedAppName(hostId: host.id), "")
    }

    func testTheAccessorysReconnectReopensAHostSessionThatDropped() async {
        model.bind(slotId: "ds", to: host.id)
        await moonlight.awaitQuiet()
        XCTAssertEqual(model.shellFacts.session?.pcName, "PC", "a host's live session is the accessory's")
        edges.onClosed?()
        let id = host.id
        let dropped = await waitUntil { [weak self] in self?.moonlight.get(id)?.phase == .failed(.dropped) }
        XCTAssertTrue(dropped)
        XCTAssertEqual(model.shellFacts.session?.phase, .stoppedResponding)
        model.reconnect()
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.phase, .streaming, "Reconnect reopens the host's session")
        XCTAssertEqual(model.shellFacts.session?.phase, .streaming)
    }

    func testBackgroundingStopsAHostSessionAndTheForegroundOpensItAgain() async {
        model.bind(slotId: "ds", to: host.id)
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.phase, .streaming)
        model.enteredBackground()
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.phase, .idle, "iOS suspends Dish, so the session stops the graceful way")
        XCTAssertEqual(moonlight.get(host.id)?.padCount, 1, "the pad stays bound")
        XCTAssertEqual(edges.liveSessions.last?.stopped, true)
        XCTAssertEqual(gateway.count(.secure, "/cancel"), 0, "the app is left for the return to resume")
        model.enteredForeground()
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.phase, .streaming)
    }

    func testTheRowActionsDispatchToTheirIntents() async {
        model.bind(slotId: "ds", to: host.id)
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.phase, .streaming)
        model.performMoonlight(.disconnect, hostId: host.id)
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.phase, .idle)
        XCTAssertEqual(moonlight.get(host.id)?.padCount, 1, "the pad stays bound")
        XCTAssertEqual(gateway.count(.secure, "/cancel"), 0, "the app is left running for the next session to resume")
        model.performMoonlight(.reconnect, hostId: host.id)
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.phase, .streaming)
        XCTAssertEqual(gateway.count(.secure, "/launch"), 2)
        model.performMoonlight(.quitApp, hostId: host.id)
        await moonlight.awaitQuiet()
        XCTAssertEqual(model.lastMoonlightEvent, .appCloseRequested(host))
        XCTAssertEqual(gateway.count(.secure, "/cancel"), 1, "closing the app is the one way to take it down")
    }
}
