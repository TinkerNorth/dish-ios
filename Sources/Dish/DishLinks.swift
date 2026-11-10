// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Every page outside the app that Dish links to. Tips are App Store
/// purchases, so the fleet's donation pages are not among them.
enum DishLinks {
    /// The fleet's website.
    static let website = URL(string: "https://dish.tinkernorth.com")
    /// This client's source.
    static let source = URL(string: "https://github.com/TinkerNorth/dish-ios")
    /// This client's privacy policy, as the repository publishes it.
    static let privacy = URL(string: "https://github.com/TinkerNorth/dish-ios/blob/main/PRIVACY.md")
    /// The free Satellite host app, as the desktops' wizard offers it.
    static let satellite = URL(string: "https://dish.tinkernorth.com/downloads/satellite")
    /// Sunshine's project page: the Moonlight host the hosts page offers
    /// when the scan finds none, as dish-mac's does.
    static let sunshine = URL(string: "https://github.com/LizardByte/Sunshine")
}

/// A link a page opens through `openURL`.
struct PageLink: Equatable, Identifiable {
    let title: String
    let url: URL?

    var id: String {
        title
    }
}
