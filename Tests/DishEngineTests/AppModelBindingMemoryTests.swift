// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// Bindings survive a restart: a binding remembered by an earlier run is
/// bound again without the user once its pad is attached and its
/// destination is known, whichever comes last; a pad that leaves and returns
/// is bound again; a forgotten satellite's bindings never come back; the
/// on-screen gamepad is bound again once it is listed; and a Moonlight
/// binding is restored the same way, with its pick.
@MainActor
final class AppModelBindingMemoryTests: XCTestCase {

    private var defaults: UserDefaults!
    private var source: FakeControllerSource!
    private var model: AppModel!
    private let den = DiscoveredServer(name: "Den", ip: "192.0.2.10", machineId: "den")
    private let host = MoonlightHost(name: "PC", address: "10.0.0.5", uniqueId: "abc")
    private let pad = ControllerSlot(id: "pad", name: "DualSense", capabilities: .none, family: .dualSense)

    override func setUp() async throws {
        try await super.setUp()
        defaults = try TestDefaults.fresh(self)
        source = FakeControllerSource(slots: [])
    }

    override func tearDown() async throws {
        model = nil
        try await super.tearDown()
    }

    /// A launch over what the earlier run left in the defaults; `known` are
    /// the satellites the earlier run paired with.
    private func launch(known: [DiscoveredServer] = []) {
        model = AppModel(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: ManualTicker(), now: Date.init),
            localNetwork: RecordedLocalNetworkAccess(),
            pads: ControllerStack(source: source, defaults: defaults),
            network: TestNetwork.stack(defaults: defaults, remembered: known),
            tips: RecordedTipStore(shelf: .success([])),
            motionSensor: FakeMotionSensor(),
            resendTicker: ManualTicker()
        )
    }

    private func rememberDenBinding(slotId: String = "pad") {
        BindingMemoryStore(defaults: defaults).remember(RememberedSatelliteBinding(slotId: slotId, satelliteId: den.id))
    }

    private func waitUntil(_ predicate: @escaping @MainActor () -> Bool) async -> Bool {
        for _ in 0 ..< 200 where !predicate() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return predicate()
    }

    /// Long enough for every settled observation to have run.
    private func settle() async {
        try? await Task.sleep(nanoseconds: 150_000_000)
    }

    private var bindings: [String: String] {
        model.network.hub.bindings
    }

    func testALaunchWithThePadPresentRestoresTheBindingAndItsPick() async {
        rememberDenBinding()
        defaults.set(["pad": "switchpro"], forKey: "emulated_type_preferences")
        source.slots = [pad]
        launch(known: [den])
        let restored = await waitUntil { self.bindings["pad"] == self.den.id }
        XCTAssertTrue(restored, "bound again without the user")
        XCTAssertEqual(model.pads.types.typeFor("pad"), .switchPro, "the pick the bind carried is the pad's own")
    }

    func testThePadAttachingLaterIsBoundAgainAndSoIsItsReturn() async {
        rememberDenBinding()
        launch(known: [den])
        await settle()
        XCTAssertNil(bindings["pad"], "no pad, nothing to bind")
        source.slots = [pad]
        let attached = await waitUntil { self.bindings["pad"] == self.den.id }
        XCTAssertTrue(attached)

        source.slots = []
        let left = await waitUntil { self.bindings.isEmpty }
        XCTAssertTrue(left, "the pad left and its binding with it")
        source.slots = [pad]
        let returned = await waitUntil { self.bindings["pad"] == self.den.id }
        XCTAssertTrue(returned, "the memory outlived the pad's absence")
    }

    func testTheSatelliteAppearingLaterIsWhenThePadIsBound() async {
        rememberDenBinding()
        source.slots = [pad]
        launch()
        await settle()
        XCTAssertNil(bindings["pad"], "the satellite is not known yet")
        model.network.wifi.store.remember(den)
        model.network.wifi.refreshRemembered()
        let restored = await waitUntil { self.bindings["pad"] == self.den.id }
        XCTAssertTrue(restored)
    }

    func testAForgottenSatellitesBindingsNeverComeBack() async {
        rememberDenBinding()
        launch(known: [den])
        model.forget(den.id)
        model.network.wifi.store.remember(den)
        model.network.wifi.refreshRemembered()
        source.slots = [pad]
        await settle()
        XCTAssertNil(bindings["pad"])
        XCTAssertEqual(BindingMemoryStore(defaults: defaults).bindings(), [])
    }

    func testUnbindingAPadErasesItsMemoryAndARestartBindsNothing() async {
        source.slots = [pad]
        launch(known: [den])
        model.bind(slotId: "pad", to: den.id)
        XCTAssertEqual(BindingMemoryStore(defaults: defaults).bindings().map(\.slotId), ["pad"])
        model.unbind(slotId: "pad")
        XCTAssertEqual(BindingMemoryStore(defaults: defaults).bindings(), [])
        launch(known: [den])
        await settle()
        XCTAssertEqual(bindings, [:])
    }

    func testTheOnScreenGamepadIsBoundAgainOnceItIsListed() async {
        rememberDenBinding(slotId: onScreenSlotId)
        launch(known: [den])
        await settle()
        XCTAssertNil(bindings[onScreenSlotId], "not listed yet")
        model.openGamepad()
        let restored = await waitUntil { self.bindings[onScreenSlotId] == self.den.id }
        XCTAssertTrue(restored)
    }

    func testARememberedMoonlightBindingIsRestoredWithItsPick() async {
        let hostStore = MoonlightHostStore(defaults: defaults)
        hostStore.put(RememberedMoonlightHost(host: host, paired: true))
        let pick = Int(MoonlightControllerType.nintendo)
        hostStore.putBinding(RememberedMoonlightBinding(slotId: pad.id, hostId: host.id, controllerType: pick))
        source.slots = [pad]
        launch()
        let restored = await waitUntil { self.bindings["pad"] == self.host.id }
        XCTAssertTrue(restored, "the Moonlight binding is read back and bound again")
        XCTAssertEqual(model.network.moonlight.rememberedBindings.first?.controllerType, pick, "the record kept its pick")
        XCTAssertEqual(model.network.moonlight.desired[host.id]?.first?.announced.type, MoonlightControllerType.nintendo)
        await model.network.moonlight.awaitQuiet()
    }
}
