// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Help & FAQ, the desktops' HelpScreen on an iPhone: a way into setup, the
/// questions in four sections, and the two links.
struct HelpPageState: Equatable {
    let title: String
    let subline: String
    let walkThrough: String
    let sections: [HelpSectionState]
    let linksTitle: String
    let links: [PageLink]
}

struct HelpSectionState: Equatable, Identifiable {
    let title: String
    let entries: [HelpEntryState]

    var id: String {
        title
    }
}

/// One question, folded until it is opened.
struct HelpEntryState: Equatable, Identifiable {
    let question: String
    let answer: String

    var id: String {
        question
    }
}

func helpPageState(words: L10n = .app) -> HelpPageState {
    HelpPageState(
        title: pageTitle(.help, words: words),
        subline: words.helpSubline,
        walkThrough: words.walkMeThroughSetup,
        sections: [concepts(words), bestPerformance(words), troubleshooting(words), aboutDish(words)],
        linksTitle: words.linksSection,
        links: [
            PageLink(title: words.privacyPolicy, url: DishLinks.privacy),
            PageLink(title: words.viewSourceOnGithub, url: DishLinks.source)
        ]
    )
}

private func concepts(_ words: L10n) -> HelpSectionState {
    HelpSectionState(title: words.conceptsSection, entries: [
        HelpEntryState(question: words.whatIsDish, answer: words.whatIsDishAnswer),
        HelpEntryState(question: words.whatIsSatellite, answer: words.whatIsSatelliteAnswer),
        HelpEntryState(question: words.howDoIConnectAController, answer: words.howDoIConnectAControllerAnswer),
        HelpEntryState(question: words.whatsMotionAndTheTouchpad, answer: words.whatsMotionAnswer)
    ])
}

private func bestPerformance(_ words: L10n) -> HelpSectionState {
    HelpSectionState(title: words.bestPerformanceSection, entries: [
        HelpEntryState(question: words.bestSetupForLowLatency, answer: words.bestSetupAnswer),
        HelpEntryState(question: words.isWiredBetter, answer: words.isWiredBetterAnswer),
        HelpEntryState(question: words.whyKeepTheScreenOn, answer: words.whyKeepTheScreenOnAnswer)
    ])
}

private func troubleshooting(_ words: L10n) -> HelpSectionState {
    HelpSectionState(title: words.troubleshootingSection, entries: [
        HelpEntryState(question: words.cantFindSatellites, answer: words.cantFindSatellitesAnswer),
        HelpEntryState(question: words.cantSeeMyNetwork, answer: words.cantSeeMyNetworkAnswer),
        HelpEntryState(question: words.controllerDoesntShowUp, answer: words.controllerDoesntShowUpAnswer),
        HelpEntryState(question: words.pinKeepsGettingRejected, answer: words.pinRejectedAnswer),
        HelpEntryState(question: words.keepsDisconnecting, answer: words.keepsDisconnectingAnswer),
        HelpEntryState(question: words.motionIsntWorking, answer: words.motionIsntWorkingAnswer)
    ])
}

private func aboutDish(_ words: L10n) -> HelpSectionState {
    HelpSectionState(title: words.aboutDishSection, entries: [
        HelpEntryState(question: words.isDishOpenSource, answer: words.isDishOpenSourceAnswer),
        HelpEntryState(question: words.whatDoesDishCollect, answer: words.whatDoesDishCollectAnswer),
        HelpEntryState(question: words.whatDoTipsPayFor, answer: words.whatDoTipsPayForAnswer)
    ])
}
