// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

extension L10n {

    // MARK: - The cover's chrome

    var setUpDish: String {
        catalog.text("Set up Dish")
    }

    var setupInputStep: String {
        catalog.text("Input · 1 of 3")
    }

    var setupDestinationStep: String {
        catalog.text("Destination · 2 of 3")
    }

    var setupBindingStep: String {
        catalog.text("Binding · 3 of 3")
    }

    var setupSkip: String {
        catalog.text("Skip")
    }

    var setupBack: String {
        catalog.text("Back")
    }

    var setupContinue: String {
        catalog.text("Continue")
    }

    // MARK: - Welcome

    var welcomeHeadline: String {
        catalog.text("Turn your iPhone into a wireless PC gamepad")
    }

    var welcomeIntro: String {
        catalog.text("Dish pairs with Satellite on your PC and sends every press over your own Wi‑Fi.")
    }

    var bringTheControllerYouOwn: String {
        catalog.text("Bring the controller you own")
    }

    var bringTheControllerYouOwnBody: String {
        paragraph(
            catalog.text("Plug in a wired pad or use one paired to this iPhone."),
            catalog.text("Dish carries it to your PC.")
        )
    }

    var orPlayOnTheScreen: String {
        catalog.text("Or play on the screen")
    }

    var orPlayOnTheScreenBody: String {
        catalog.text("On-screen gamepad and touchpad, with gyro aim and rumble.")
    }

    var staysOnYourNetwork: String {
        catalog.text("Stays on your network")
    }

    var staysOnYourNetworkBody: String {
        paragraph(catalog.text("Encrypted and LAN-only."), catalog.text("No account, no tracking."))
    }

    var getSatelliteForYourPC: String {
        catalog.text("Get Satellite for your PC")
    }

    // MARK: - Input · 1 of 3

    var howDoYouWantToPlay: String {
        catalog.text("How do you want to play?")
    }

    var howDoYouWantToPlayBody: String {
        paragraph(catalog.text("Pick an input."), catalog.text("Each sets up a little differently."))
    }

    var foundOnThisIPhone: String {
        catalog.text("Found on this iPhone")
    }

    var setupUse: String {
        catalog.text("Use")
    }

    var orChoose: String {
        catalog.text("Or choose")
    }

    var wiredController: String {
        catalog.text("Wired controller")
    }

    var wiredControllerBody: String {
        paragraph(catalog.text("Plugged into your iPhone’s USB-C port."), catalog.text("Lowest latency."))
    }

    var bluetoothController: String {
        catalog.text("Bluetooth controller")
    }

    var bluetoothControllerBody: String {
        catalog.text("A pad paired to this iPhone in Settings › Bluetooth.")
    }

    var onScreenGamepad: String {
        catalog.text("On-screen gamepad")
    }

    var onScreenGamepadBody: String {
        catalog.text("Touch buttons on the glass.")
    }

    var setupBest: String {
        catalog.text("Best")
    }

    var dishReadsAnyController: String {
        catalog.text("Dish reads any controller iOS supports: DualSense, DualShock 4, Xbox Wireless and Switch Pro.")
    }

    var pluggedIn: String {
        catalog.text("Plugged in")
    }

    var setupConnected: String {
        catalog.text("Connected")
    }

    var usbC: String {
        catalog.text("USB-C")
    }

    var setupBluetooth: String {
        catalog.text("Bluetooth")
    }

    var setupThisIPhone: String {
        catalog.text("This iPhone")
    }

    func setupBattery(_ percent: Int) -> String {
        catalog.format("%lld%%", percent)
    }

    // MARK: - Destination · 2 of 3: the Local Network primer

    var setupYourPC: String {
        catalog.text("Your PC")
    }

    var letDishFindYourPC: String {
        catalog.text("Let Dish find your PC")
    }

    var letDishFindYourPCBody: String {
        paragraph(
            catalog.text("Satellite announces itself on your Wi‑Fi."),
            catalog.text("iOS asks before any app looks for devices on your network.")
        )
    }

    var onlyThisWiFi: String {
        catalog.text("Only this Wi‑Fi")
    }

    var onlyThisWiFiBody: String {
        catalog.text("Bonjour discovery, the way AirPlay finds a TV.")
    }

    var nothingPairsWithoutAPIN: String {
        catalog.text("Nothing pairs without a PIN")
    }

    var nothingPairsWithoutAPINBody: String {
        catalog.text("Satellite shows a 4-digit PIN on your PC.")
    }

    var yoursToChangeLater: String {
        catalog.text("Yours to change later")
    }

    var yoursToChangeLaterBody: String {
        catalog.text("Settings › Privacy & Security › Local Network")
    }

    var addMyPCByAddressInstead: String {
        catalog.text("Add my PC by address instead")
    }

    // MARK: - Destination · 2 of 3: Pick your PC

    var pickYourPC: String {
        catalog.text("Pick your PC")
    }

    var pickYourPCBody: String {
        catalog.text("PCs running Satellite on this Wi‑Fi show up here.")
    }

    var setupSatellite: String {
        catalog.text("Satellite")
    }

    var setupFastest: String {
        catalog.text("Fastest")
    }

    var setupFast: String {
        catalog.text("Fast")
    }

    var setupSearching: String {
        catalog.text("Searching")
    }

    var setupNeedsPairing: String {
        catalog.text("Needs pairing")
    }

    var setupPaired: String {
        catalog.text("Paired")
    }

    var noPCsFoundYet: String {
        catalog.text("No PCs found yet.")
    }

    var useAMoonlightHost: String {
        catalog.text("Use a Moonlight host")
    }

    var useAMoonlightHostBody: String {
        paragraph(catalog.text("Sunshine, Apollo or Wolf."), catalog.text("No Satellite needed."))
    }

    var addAPCByAddress: String {
        catalog.text("Add a PC by address")
    }

    var dontSeeYourPC: String {
        paragraph(
            catalog.text("Don’t see your PC?"),
            catalog.text("Start Satellite on it and check that both are on the same Wi‑Fi.")
        )
    }

    var setupCantSeeYourNetwork: String {
        catalog.text("Dish can’t see your network")
    }

    var setupCantSeeYourNetworkBody: String {
        paragraph(
            catalog.text("Local Network is off for Dish, so it can’t find Satellite or send input to your PC."),
            catalog.text("Turn it on and Dish picks up where it left off.")
        )
    }

    var setupOpenSettings: String {
        catalog.text("Open Settings")
    }

    var setupLocalNetworkSettingsPath: String {
        catalog.text("Settings › Dish › Local Network")
    }

    // MARK: - Binding · 3 of 3

    var reviewAndBind: String {
        catalog.text("Review and bind")
    }

    var reviewAndBindBody: String {
        paragraph(catalog.text("Check the link, then bind it."), catalog.text("Nothing changes on your PC until you do."))
    }

    var aPCByAddress: String {
        catalog.text("A PC by address")
    }

    var setupEmulateAs: String {
        catalog.text("Emulate as")
    }

    var setupMotion: String {
        catalog.text("Motion")
    }

    var dualSense: String {
        catalog.text("DualSense")
    }

    var dualShock4: String {
        catalog.text("DualShock 4")
    }

    var xboxWireless: String {
        catalog.text("Xbox Wireless")
    }

    var switchPro: String {
        catalog.text("Switch Pro")
    }

    var dualSenseCarries: String {
        catalog.text("DualSense carries motion, touchpad and adaptive triggers.")
    }

    var dualShock4Carries: String {
        catalog.text("DualShock 4 carries motion, touchpad and the light bar.")
    }

    var xboxWirelessCarries: String {
        catalog.text("Xbox Wireless carries rumble, without motion or a touchpad.")
    }

    var switchProCarries: String {
        catalog.text("Switch Pro carries motion and rumble.")
    }

    var theOtherPadsAreInTheMenu: String {
        catalog.text("The other pads are in the menu.")
    }

    var whatCarries: String {
        catalog.text("What carries")
    }

    var sendsToPC: String {
        catalog.text("Sends to PC")
    }

    var getsBack: String {
        catalog.text("Gets back")
    }

    var buttonsSticks: String {
        catalog.text("Buttons, sticks")
    }

    var carriesTouchpad: String {
        catalog.text("Touchpad")
    }

    var carriesBattery: String {
        catalog.text("Battery")
    }

    var carriesRumble: String {
        catalog.text("Rumble")
    }

    var triggerEffects: String {
        catalog.text("Trigger effects")
    }

    var lightBar: String {
        catalog.text("Light bar")
    }

    var carriesSpeaker: String {
        catalog.text("Speaker")
    }

    var setupBind: String {
        catalog.text("Bind")
    }
}
