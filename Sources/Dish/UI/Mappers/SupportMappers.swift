// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// The tips heart, on the Controllers toolbar, Settings › About and the
/// Support Dish page.
let heartSymbol = "heart.fill"

/// One tip's button: its name and the App Store's price for it.
struct TipButtonState: Equatable, Identifiable {
    let tier: TipTier
    let title: String
    /// StoreKit's own localized price, unchanged.
    let price: String
    /// This tip is the one waiting on the App Store.
    let busy: Bool
    let enabled: Bool

    var id: TipTier {
        tier
    }
}

/// What the TIPS section shows.
enum SupportShelfState: Equatable {
    case loading(String)
    case tips([TipButtonState])
    case unavailable(message: String, retry: String)
}

/// The word under the tips after a tip or a Restore.
enum SupportNoticeState: Equatable {
    case none
    case thanks(title: String, body: String)
    case note(text: String, color: Color)
}

/// Support Dish: the heart, the pitch, the tips, the outcome and Restore.
struct SupportPageState: Equatable {
    let title: String
    let heartSymbol: String
    let pitch: String
    let tipsTitle: String
    let shelf: SupportShelfState
    let notice: SupportNoticeState
    let restoreTitle: String
    let restoreEnabled: Bool
    let footnote: String
}

func supportPageState(support: SupportFacts, words: L10n = .app) -> SupportPageState {
    let idle = !support.busy
    return SupportPageState(
        title: pageTitle(.support, words: words),
        heartSymbol: heartSymbol,
        pitch: words.supportPitch,
        tipsTitle: words.tips,
        shelf: supportShelf(support, words: words),
        notice: supportNotice(support.moment, words: words),
        restoreTitle: words.restorePurchases,
        restoreEnabled: idle && support.shelf != .loading,
        footnote: words.supportFootnote
    )
}

private func supportShelf(_ support: SupportFacts, words: L10n) -> SupportShelfState {
    switch support.shelf {
    case .loading: .loading(words.loading)
    case let .ready(products): .tips(products.map { tipButton($0, support: support, words: words) })
    case .unavailable: .unavailable(message: words.tipsUnavailable, retry: words.tryAgain)
    }
}

private func tipButton(_ product: TipProduct, support: SupportFacts, words: L10n) -> TipButtonState {
    TipButtonState(
        tier: product.tier,
        title: tipTitle(product.tier, words: words),
        price: product.displayPrice,
        busy: support.moment == .buying(product.tier),
        enabled: !support.busy
    )
}

func tipTitle(_ tier: TipTier, words: L10n = .app) -> String {
    switch tier {
    case .small: words.smallTip
    case .medium: words.mediumTip
    case .large: words.largeTip
    }
}

private func supportNotice(_ moment: TipMoment, words: L10n) -> SupportNoticeState {
    switch moment {
    case .idle, .buying, .restoring: .none
    case .thanked: .thanks(title: words.thankYou, body: words.thankYouBody)
    case .pending: .note(text: words.tipPending, color: DishTheme.muted)
    case .failed: .note(text: words.tipFailed, color: DishTheme.error)
    case .nothingToRestore: .note(text: words.nothingToRestore, color: DishTheme.muted)
    }
}
