// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// Support Dish's intents. Each returns the task that asks the App Store, so
/// a test can wait for the answer; a view drops it.
package extension AppModel {
    @discardableResult
    func loadTips() -> Task<Void, Never> {
        Task { await fetchTips() }
    }

    /// Ignored while another tip or a Restore is waiting on the App Store.
    @discardableResult
    func tip(_ tier: TipTier) -> Task<Void, Never> {
        guard !supportSource.state.busy else { return Task {} }
        setTipMoment(.buying(tier))
        return Task { await buyTip(tier) }
    }

    @discardableResult
    func restoreTips() -> Task<Void, Never> {
        guard !supportSource.state.busy else { return Task {} }
        setTipMoment(.restoring)
        return Task { await restorePurchases() }
    }
}

extension AppModel {
    private func fetchTips() async {
        let shelf: TipShelf
        do {
            shelf = try await tipShelf(tips.products())
        } catch {
            shelf = .unavailable
        }
        supportSource.updateState { $0.with(shelf: shelf) }
    }

    private func buyTip(_ tier: TipTier) async {
        let moment: TipMoment
        do {
            moment = try await tipMoment(after: tips.purchase(tier))
        } catch {
            moment = .failed
        }
        setTipMoment(moment)
    }

    private func restorePurchases() async {
        let moment: TipMoment
        do {
            let found = try await tips.restore()
            moment = found ? .thanked : .nothingToRestore
        } catch {
            moment = .failed
        }
        setTipMoment(moment)
    }

    private func setTipMoment(_ moment: TipMoment) {
        supportSource.updateState { $0.with(moment: moment) }
    }
}

/// The App Store's products smallest first; none is no shelf at all.
func tipShelf(_ products: [TipProduct]) -> TipShelf {
    let ordered = TipTier.allCases.compactMap { tier in products.first { $0.tier == tier } }
    return ordered.isEmpty ? .unavailable : .ready(ordered)
}

func tipMoment(after purchase: TipPurchase) -> TipMoment {
    switch purchase {
    case .completed: .thanked
    case .cancelled: .idle
    case .pending: .pending
    }
}
