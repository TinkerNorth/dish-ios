// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import Foundation

/// The note a Lightning iPhone shows wherever a wired pad is offered.
struct AdapterNoteState: Equatable {
    let symbol: String
    let title: String
    let body: String
    /// The way to the sheet.
    let more: String
}

/// The bolt, which is the Lightning mark.
let lightningSymbol = "bolt.fill"

/// The note for a Lightning iPhone; nil on a USB-C one.
func adapterNote(port: DevicePort, words: L10n = .app) -> AdapterNoteState? {
    switch port {
    case .usbC: nil
    case .lightning: AdapterNoteState(
            symbol: lightningSymbol,
            title: words.lightningPort,
            body: words.wiredNeedsTheAdapter,
            more: words.whatYouNeed
        )
    }
}

/// The word for a pad attached to the device: the port it is attached to.
func wiredLinkWord(_ port: DevicePort, words: L10n = .app) -> String {
    switch port {
    case .usbC: words.linkUsbC
    case .lightning: words.linkLightning
    }
}

/// A tile of the sheet's illustration: a symbol and the eyebrow under it.
struct AdapterTile: Equatable {
    let symbol: String
    let label: String
}

/// One of the sheet's steps: a glyph and the sentence.
struct AdapterStep: Equatable, Identifiable {
    let symbol: String
    let text: String

    var id: String {
        text
    }
}

/// The sheet behind the note: Wired on this iPhone.
struct LightningAdapterSheetState: Equatable {
    let title: String
    let thisIPhone: AdapterTile
    let adapterLabel: String
    let controller: AdapterTile
    let headline: String
    let body: String
    let stepsTitle: String
    let steps: [AdapterStep]
    let note: String
    let adapterLink: PageLink
    let done: String
}

func lightningAdapterSheetState(words: L10n = .app) -> LightningAdapterSheetState {
    LightningAdapterSheetState(
        title: words.wiredOnThisIPhone,
        thisIPhone: AdapterTile(symbol: "iphone", label: words.thisIPhone),
        adapterLabel: words.adapter,
        controller: AdapterTile(symbol: "gamecontroller", label: words.controller),
        headline: words.thisIPhoneHasALightningPort,
        body: paragraph(words.aLightningCableCannotCarryAPad, words.wiredNeedsTheAdapter),
        stepsTitle: words.whatYouNeed,
        steps: [
            AdapterStep(symbol: "cable.connector", text: words.plugTheAdapterIn),
            AdapterStep(symbol: "gamecontroller", text: words.plugTheControllerIntoTheAdapter),
            AdapterStep(symbol: "powerplug.fill", text: words.powerTheAdapter)
        ],
        note: words.bluetoothNeedsNoAdapter,
        adapterLink: PageLink(title: words.applesAdapter, url: DishLinks.lightningAdapter),
        done: words.done
    )
}
