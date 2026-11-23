// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Diagnostics › a controller › Controller tests: each test, its note, the
/// stick tests' lines and "Did it work?", in dish-mac's and dish-android's
/// words where they have them.
extension L10n {

    // MARK: - The page

    var controllerTests: String {
        catalog.text("Controller tests")
    }

    var testThisController: String {
        catalog.text("Test this controller")
    }

    var benchIntro: String {
        catalog.text("Each test drives the controller from here alone, with no PC in the loop.")
    }

    var nothingToTestHere: String {
        catalog.text("Nothing on this controller’s path can be tested from here.")
    }

    // MARK: - The items

    var triggerRumble: String {
        catalog.text("Trigger rumble")
    }

    var stickTests: String {
        catalog.text("Stick tests")
    }

    var rumbleTestNote: String {
        catalog.text("A short buzz straight to the controller, whatever its rumble switch says.")
    }

    var triggerRumbleTestNote: String {
        catalog.text("A short buzz in the triggers’ own motors, whatever the controller’s rumble switch says.")
    }

    var lightbarTestNote: String {
        catalog.text("Red, green, then blue, then back to what the game set.")
    }

    var playerLedsTestNote: String {
        catalog.text("Players one to four, then back to what the game set.")
    }

    var triggerPulseNote: String {
        catalog.text("Both triggers stiffen for two seconds, then go back to what the game set.")
    }

    var stickTestsReadRaw: String {
        catalog.text("The tests read the sticks as the controller sends them, before the dead zones.")
    }

    // MARK: - The tests

    var weakMotor: String {
        catalog.text("Weak motor")
    }

    var strongMotor: String {
        catalog.text("Strong motor")
    }

    var bothMotors: String {
        catalog.text("Both motors")
    }

    /// The phone's one actuator, which plays both motors as one.
    var shortBuzz: String {
        catalog.text("Short buzz")
    }

    var leftTriggerMotor: String {
        catalog.text("Left trigger motor")
    }

    var rightTriggerMotor: String {
        catalog.text("Right trigger motor")
    }

    var bothTriggerMotors: String {
        catalog.text("Both trigger motors")
    }

    var lightbarCycle: String {
        catalog.text("Light bar cycle")
    }

    var playerLedCycle: String {
        catalog.text("Player LED cycle")
    }

    var triggerResistance: String {
        catalog.text("Trigger resistance")
    }

    var driftTestButton: String {
        catalog.text("Drift test (hands off the sticks)")
    }

    var rangeTestButton: String {
        catalog.text("Range test (sweep full circles)")
    }

    var driftTest: String {
        catalog.text("Drift test")
    }

    var rangeTest: String {
        catalog.text("Range test")
    }

    // MARK: - The stick tests' line

    func capturingSeconds(_ seconds: Int) -> String {
        catalog.format("Capturing… %lld s", seconds)
    }

    var testSawNothing: String {
        catalog.text("The controller sent nothing during the test.")
    }

    func restingDrift(_ left: String, _ right: String) -> String {
        catalog.format("Resting drift: L %@ · R %@.", left, right)
    }

    func suggestedDeadZone(_ zone: String) -> String {
        catalog.format("Suggested dead zone: %@.", zone)
    }

    func stickReach(_ left: String, _ right: String) -> String {
        catalog.format("Reach: L %@ · R %@.", left, right)
    }

    func circularityError(_ left: String, _ right: String) -> String {
        catalog.format("Circularity error: L %@ · R %@.", left, right)
    }

    /// A roundness the sweep never covered enough of the circle to judge.
    var notApplicable: String {
        catalog.text("n/a")
    }

    // MARK: - Did it work?

    var didItWork: String {
        catalog.text("Did it work?")
    }

    func didTestWork(_ test: String) -> String {
        catalog.format("%@: did it work?", test)
    }

    var itWorked: String {
        catalog.text("It worked")
    }

    var itDidNotWork: String {
        catalog.text("It didn’t work")
    }

    var benchAnswersHint: String {
        paragraph(
            catalog.text("Run a test above, then say whether it worked."),
            catalog.text("Your answers go in the support file.")
        )
    }
}
