// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Help & FAQ, the desktops' HelpScreen reworded where an iPhone differs:
/// pads pair in Settings › Bluetooth, iOS asks for the Local Network once,
/// and iOS suspends a Dish that is not on screen. A sentence the desktops
/// share keeps their key, so it keeps their translations.
extension L10n {

    var helpAndFaq: String {
        catalog.text("Help & FAQ")
    }

    var helpSubline: String {
        catalog.text("How Dish works, and what to try when it doesn’t")
    }

    var walkMeThroughSetup: String {
        catalog.text("Walk me through setup")
    }

    var viewSourceOnGithub: String {
        catalog.text("View source on GitHub")
    }

    var privacyPolicy: String {
        catalog.text("Privacy policy")
    }

    // MARK: - Sections

    var conceptsSection: String {
        catalog.text("CONCEPTS")
    }

    var bestPerformanceSection: String {
        catalog.text("BEST PERFORMANCE")
    }

    var troubleshootingSection: String {
        catalog.text("TROUBLESHOOTING")
    }

    var aboutDishSection: String {
        catalog.text("ABOUT DISH")
    }

    var linksSection: String {
        catalog.text("LINKS")
    }

    // MARK: - Concepts

    var whatIsDish: String {
        catalog.text("What is Dish?")
    }

    var whatIsDishAnswer: String {
        paragraph(
            catalog
                .text("Dish turns a controller paired with this iPhone, or the iPhone’s own screen, into a wireless gamepad for your PC."),
            catalog.text("It forwards input over your local network to the free Satellite helper.")
        )
    }

    var whatIsSatellite: String {
        catalog.text("What is Satellite?")
    }

    var whatIsSatelliteAnswer: String {
        paragraph(
            catalog.text("Satellite is a small, free, open-source program that runs on the host PC."),
            catalog.text("It receives input from Dish over Wi-Fi and presents itself to that PC’s games as a regular controller."),
            catalog.text("Without Satellite, games can’t see your controller."),
            catalog.text("Install it from dish.tinkernorth.com/downloads/satellite.")
        )
    }

    var howDoIConnectAController: String {
        catalog.text("How do I connect a controller?")
    }

    var howDoIConnectAControllerAnswer: String {
        paragraph(
            catalog.text("Pair it with this iPhone in Settings › Bluetooth, or plug it in with a cable."),
            catalog.text("Apps can’t pair Bluetooth devices, so Dish leaves that to iOS."),
            catalog.text("Once iOS sees the controller, it appears on the Controllers tab.")
        )
    }

    var whatsMotionAndTheTouchpad: String {
        catalog.text("What’s motion and what’s the touchpad?")
    }

    var whatsMotionAnswer: String {
        paragraph(
            catalog.text("Motion is a controller’s gyroscope used as aim assist, forwarded as the gyro inside a PlayStation pad."),
            catalog.text("The touchpad forwards a DualSense / DualShock 4 touchpad."),
            catalog.text("Both need a PlayStation-style controller and a Satellite connection.")
        )
    }

    // MARK: - Best performance

    var bestSetupForLowLatency: String {
        catalog.text("What’s the best setup for low latency?")
    }

    var bestSetupAnswer: String {
        paragraph(
            catalog.text("Put the PC on wired Ethernet and this iPhone on 5 GHz Wi-Fi, both on the same router."),
            catalog.text("Dish sends input as small UDP packets over your local network, so a fast LAN keeps the delay tiny.")
        )
    }

    var isWiredBetter: String {
        catalog.text("Is wired better than wireless?")
    }

    var isWiredBetterAnswer: String {
        paragraph(
            catalog.text("For the controller-to-iPhone leg, a wired controller has no radio latency."),
            catalog.text("For the iPhone-to-PC leg, Wi-Fi is the only way, so connect the PC to the router with Ethernet if you can.")
        )
    }

    var whyKeepTheScreenOn: String {
        catalog.text("Why does Dish keep the screen on?")
    }

    var whyKeepTheScreenOnAnswer: String {
        paragraph(
            catalog.text("iOS suspends an app you leave, and a suspended Dish stops forwarding."),
            catalog.text("While a controller is forwarded, Dish keeps the screen on and dims it instead of locking."),
            catalog.text("Tap the dimmed screen to wake it, and set the delay in Settings › Dim screen after.")
        )
    }

    // MARK: - Troubleshooting

    var cantFindSatellites: String {
        catalog.text("Dish can’t find any satellites. What now?")
    }

    var cantFindSatellitesAnswer: String {
        paragraph(
            catalog.text("Check that Satellite is running on the PC."),
            catalog.text("Confirm this iPhone and the PC are on the same Wi-Fi network."),
            catalog.text("Guest networks and 2.4 GHz vs 5 GHz on the same router count as different.")
        )
    }

    var cantSeeMyNetwork: String {
        catalog.text("Dish can’t see my network.")
    }

    var cantSeeMyNetworkAnswer: String {
        paragraph(
            catalog.text("iOS asks once whether Dish may use the local network, the first time Dish looks for your PC."),
            catalog.text("If you chose Don’t Allow, turn Dish on in Settings › Privacy & Security › Local Network."),
            catalog.text("Without it, Dish can’t find or reach your PC.")
        )
    }

    var controllerDoesntShowUp: String {
        catalog.text("My controller doesn’t show up.")
    }

    var controllerDoesntShowUpAnswer: String {
        paragraph(
            catalog.text("Pair it in Settings › Bluetooth first, or plug it in."),
            catalog.text("A controller last paired with another device, such as a console, has to be paired with this iPhone again."),
            catalog.text("Dish lists every pad iOS supports and marks one it can’t read as Not supported.")
        )
    }

    var pinKeepsGettingRejected: String {
        catalog.text("My PIN keeps getting rejected.")
    }

    var pinRejectedAnswer: String {
        let shown = catalog.text(
            "The PIN is shown by Satellite on the host PC and changes if you restart it."
        )
        let check = catalog.text(
            "Check the digits right before you type, and make sure you’re pairing with the right Satellite if more than one is listed."
        )
        return paragraph(shown, check)
    }

    var keepsDisconnecting: String {
        catalog.text("My controller keeps disconnecting mid-game.")
    }

    var keepsDisconnectingAnswer: String {
        paragraph(
            catalog.text("Most disconnects come from Wi-Fi switching bands or the controller’s own wireless dropping."),
            catalog.text("Keep the controller close to this iPhone and the PC on wired Ethernet."),
            catalog.text("Dish keeps the session alive while the app is open."),
            catalog.text("Leaving Dish stops forwarding, because iOS suspends it.")
        )
    }

    var motionIsntWorking: String {
        catalog.text("Motion (gyro aim) isn’t working.")
    }

    var motionIsntWorkingAnswer: String {
        let needs = catalog.text(
            "Motion needs three things: a Satellite connection, a controller with a gyroscope (DualSense, DualShock 4, Switch Pro),"
        )
        let type = catalog.text(
            "and a PlayStation-style controller type on the slot."
        )
        let fix = catalog.text(
            "Set Emulate as to DualSense or DualShock 4 on the controller’s page to enable the motion channel."
        )
        return paragraph(needs, type, fix)
    }

    // MARK: - About Dish

    var isDishOpenSource: String {
        catalog.text("Is Dish open source?")
    }

    var isDishOpenSourceAnswer: String {
        let yes = catalog.text(
            "Yes."
        )
        let licence = catalog.text(
            "Dish (iOS, Windows, Android, Linux, Mac) and Satellite are all released under LGPL-3.0."
        )
        let source = catalog.text(
            "The source is on GitHub at github.com/TinkerNorth."
        )
        let welcome = catalog.text(
            "Pull requests welcome."
        )
        return paragraph(yes, licence, source, welcome)
    }

    var whatDoesDishCollect: String {
        catalog.text("What does Dish collect?")
    }

    var whatDoesDishCollectAnswer: String {
        paragraph(
            catalog.text("Almost nothing."),
            catalog.text("Dish doesn’t send gameplay or controller input anywhere except the host PC on your local network."),
            catalog.text("It has no analytics and no crash reporting."),
            catalog.text("See the privacy policy for the full list.")
        )
    }

    var whatDoTipsPayFor: String {
        catalog.text("What do tips pay for?")
    }

    var whatDoTipsPayForAnswer: String {
        paragraph(
            catalog.text("Tips are App Store in-app purchases that unlock nothing: every feature of Dish stays free."),
            catalog.text("They pay for the time that goes into Dish and Satellite.")
        )
    }
}
