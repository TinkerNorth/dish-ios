// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Report a problem and Ask a question: the categories, the prompt, the
/// controller pick, what the file holds in plain words, and the two actions.
extension L10n {

    var reportAProblem: String {
        catalog.text("Report a problem")
    }

    var askAQuestion: String {
        catalog.text("Ask a question")
    }

    // MARK: - The category

    var reportCategory: String {
        catalog.text("What is it about?")
    }

    var chooseACategory: String {
        catalog.text("Choose one")
    }

    var categoryNotRecognised: String {
        catalog.text("Controller not recognised")
    }

    var categoryNoFeedback: String {
        catalog.text("No rumble or feedback")
    }

    var categoryConnection: String {
        catalog.text("Connection or latency")
    }

    var categoryAudio: String {
        catalog.text("Audio")
    }

    var categoryOther: String {
        catalog.text("Something else")
    }

    var categoryQuestion: String {
        catalog.text("A question")
    }

    // MARK: - The person's words and the controller

    var reportPrompt: String {
        catalog.text("What happened, and what did you expect?")
    }

    var noController: String {
        catalog.text("None")
    }

    // MARK: - What the file holds

    var theFileWillHold: String {
        catalog.text("The file will hold")
    }

    var holdsYourWords: String {
        catalog.text("Your words and the category you picked")
    }

    var holdsThisDevice: String {
        catalog.text("Dish's version, this device's model and iOS version, its battery, temperature and Low Power Mode")
    }

    var holdsControllerData: String {
        catalog.text("The controller data's version and its last check")
    }

    var holdsControllers: String {
        catalog.text("Each controller's name, how it connects, and counts of what it sent and what it was sent")
    }

    var holdsHosts: String {
        catalog.text("Each PC as Host 1, Host 2: its version, its session as Dish sees it, and what the PC says of it")
    }

    var holdsEvents: String {
        catalog.text("The events Diagnostics recorded")
    }

    // MARK: - The actions

    var previewFile: String {
        catalog.text("Preview file")
    }

    var continueInMail: String {
        catalog.text("Continue in Mail")
    }

    var preparingTheFile: String {
        catalog.text("Asking your PCs and writing the file…")
    }

    var fileNotWritten: String {
        catalog.text("The file could not be written. Try again.")
    }
}
