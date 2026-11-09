// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// Each controller's own switches, stored as the fleet stores them, and the
/// global switches above them.
@MainActor
final class SlotPreferencesTests: XCTestCase {

    func testTheEffectiveSwitchNeedsBothTheGlobalAndTheControllersOwn() {
        let global = ForwardingFlags(motion: false, rumble: true, lightbar: false)
        let slot = SlotPreferences(rumble: false, triggerEffects: false)
        let flags = effectiveFlags(global: global, slot: slot)
        XCTAssertFalse(flags.motion, "global off")
        XCTAssertFalse(flags.rumble, "the controller's own off")
        XCTAssertFalse(flags.lightbar, "global off")
        XCTAssertTrue(flags.touchpad, "both on")
        XCTAssertFalse(flags.triggerEffects, "no global switch: the controller's own")
        XCTAssertTrue(flags.playerLeds)
    }

    func testAControllerNeverSwitchedReadsAllOn() throws {
        let store = try SlotPreferenceStore(defaults: TestDefaults.fresh(self))
        XCTAssertEqual(store.preferences(for: "pad"), SlotPreferences())
        XCTAssertTrue(SlotSwitch.allCases.allSatisfy { store.preferences(for: "pad").isOn($0) })
    }

    func testEachSwitchIsWrittenAndReadBackPerController() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = SlotPreferenceStore(defaults: defaults)
        for toggle in SlotSwitch.allCases {
            store.set(toggle, false, for: "a")
        }
        store.set(.rumble, false, for: "b")
        let reread = SlotPreferenceStore(defaults: defaults)
        XCTAssertTrue(SlotSwitch.allCases.allSatisfy { !reread.preferences(for: "a").isOn($0) })
        XCTAssertEqual(reread.preferences(for: "b"), SlotPreferences(rumble: false))
    }

    func testTheRowsAreTheFleetsShape() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = SlotPreferenceStore(defaults: defaults)
        store.set(.motion, false, for: "pad")
        XCTAssertEqual(defaults.string(forKey: "motion_preferences"), #"[{"enabled":false,"slotId":"pad"}]"#)
        XCTAssertEqual(defaults.string(forKey: "rumble_preferences"), #"[{"enabled":true,"slotId":"pad"}]"#)
        for key in ["touchpad_preferences", "lightbar_preferences", "trigger_effects_preferences", "player_leds_preferences"] {
            XCTAssertNotNil(defaults.string(forKey: key), key)
        }
    }

    func testAGarbledBlobReadsAsNothingWritten() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set("not json", forKey: "motion_preferences")
        defaults.set(#"[{"slotId":"pad"},{"slotId":"","enabled":false},{"slotId":"ok","enabled":false}]"#, forKey: "rumble_preferences")
        let store = SlotPreferenceStore(defaults: defaults)
        XCTAssertEqual(store.state, ["ok": SlotPreferences(rumble: false)])
    }

    func testTheSameSwitchTwiceIsOneChange() throws {
        let defaults = try TestDefaults.fresh(self)
        let store = SlotPreferenceStore(defaults: defaults)
        store.set(.motion, true, for: "pad")
        XCTAssertNil(defaults.string(forKey: "motion_preferences"), "a switch already on writes nothing")
        store.set(.motion, false, for: "pad")
        store.set(.motion, false, for: "pad")
        XCTAssertEqual(store.state.count, 1)
    }

    func testOnlyTheSwitchesThePadHasTheHardwareForAreCarried() {
        let dualSense = ControllerCapabilities(
            hasMotion: true, hasTouchpad: true, hasRumble: true, hasLightbar: true, hasTriggerEffects: true, hasPlayerLeds: true
        )
        XCTAssertEqual(SlotSwitch.allCases.filter { $0.isCarried(by: dualSense) }, SlotSwitch.allCases)
        let xbox = ControllerCapabilities(hasRumble: true)
        XCTAssertEqual(SlotSwitch.allCases.filter { $0.isCarried(by: xbox) }, [.rumble])
    }

    // MARK: - The global switches

    func testFreshInstallDefaultsEverythingOn() throws {
        let settings = try FeatureSettings(defaults: TestDefaults.fresh(self))
        XCTAssertEqual(settings.flags, ForwardingFlags())
        XCTAssertEqual(settings.lightbarMode, .followGame)
    }

    func testEveryTogglePersistsIndependentlyUnderTheFleetsKeys() throws {
        let defaults = try TestDefaults.fresh(self)
        let settings = FeatureSettings(defaults: defaults)
        settings.setMotion(false)
        settings.setLightbarMode(.off)
        let reread = FeatureSettings(defaults: defaults)
        XCTAssertEqual(reread.flags, ForwardingFlags(motion: false, lightbar: false))
        XCTAssertEqual(defaults.object(forKey: "feature_motion_enabled") as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: "feature_lightbar_mode"), "off")
        settings.setRumble(false)
        settings.setTouchpad(false)
        XCTAssertEqual(
            FeatureSettings(defaults: defaults).flags,
            ForwardingFlags(motion: false, touchpad: false, rumble: false, lightbar: false)
        )
    }

    func testLightbarModeRawValuesAreStable() {
        XCTAssertEqual(LightbarMode.followGame.rawValue, "followGame")
        XCTAssertEqual(LightbarMode.off.rawValue, "off")
    }
}
