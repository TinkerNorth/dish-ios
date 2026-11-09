# dish-ios: Design tokens

Every design value lives in [Sources/Dish/UI/Theme.swift](Sources/Dish/UI/Theme.swift):
the palette as `DishTheme`, the type scale as `DishFont`, the kit's measures
as `DishSize`, the spacing scale as `DishSpace`, the SF Symbols the setup
chrome draws as `DishSymbol` and the package's images as `DishImage`. A view
outside that file writes no raw colour, derives no colour from a token, and
sets no raw font size; a kit component (`Sources/Dish/UI/Kit`) sets no raw
size either. `Tests/ArchitectureTests/ThemeTokenTests.swift` fails the build on
any of them, fails it when a token below is missing from this page, and fails
it again when a token outside the shared palette is declared and never drawn.

The design handoff, with the boards these values were read from, is
[docs/design/README.md](docs/design/README.md) ("Visual tokens"); this page
restates only what the code declares. Palette names follow the cross-repo
schema (the TinkerNorth `BRAND.md`). When a shared value changes, change the
matching token in dish-android, dish-mac, dish-linux, dish-windows and the
Satellite web UI in the same breath.

iOS 26 draws the tab bar, the toolbars, the lists' corners and the glass. None
of that is a token here, and nothing restyles it.

## Palette (`DishTheme`)

Cyan on deep space in the dark, the light palette of the design's D5 board in
the light. Every colour token is one `Color(dark:light:alpha:)`, resolved
through `UIColor`'s dynamic provider at draw time, so a view never asks which
appearance is on: the Appearance setting (System, Light, Dark) sets the
scene's colour scheme with `preferredColorScheme`, and the tokens follow it.
The setting defaults to System, so the dark palette is what a dark iPhone
shows, not an unconditional default (the design README calls dark "the
default"; `Tests/PARITY.md` lists the difference).

| Token | Dark | Light | Role |
|---|---|---|---|
| `DishTheme.background` | `0x060818` | `0xF2F4F8` | A page's ground (`--tn-ink`) |
| `DishTheme.surface` | `0x0C1027` | `0xFFFFFF` | List rows and grouped sections (`--tn-night`) |
| `DishTheme.surfaceDim` | `0x131A3A` | `0xE7ECF6` | The glyph tile behind a row's symbol (`--tn-deep`) |
| `DishTheme.primary` | `0x4FE3FF` | `0x0E7C97` | The accent (`--tn-signal`) |
| `DishTheme.primaryDark` | `0x2C93AD` | `0x0A5E73` | Pressed and disabled accent (`--tn-signal-dim`) |
| `DishTheme.onPrimary` | `0x060818` | `0xFFFFFF` | Text and glyphs on the accent |
| `DishTheme.onSurface` | `0xE6ECFF` | `0x0C1430` | Body text (`--body-color`) |
| `DishTheme.muted` | `0x93A0C8` | `0x5A6680` | Secondary text and resting dots (`--muted`) |
| `DishTheme.outline` | accent @ 18 % | accent @ 18 % | Dividers and outlined chips |
| `DishTheme.success` | `0x22C55E` | `0x1B873F` | Online, on, a carried capability |
| `DishTheme.error` | `0xFF6B5C` | `0xC0392B` | Errors, a lost link, a low battery, the stopped session's glyph |
| `DishTheme.warning` | `0xF59E0B` | `0xB7791F` | Unsteady, needs pairing, a PC still to be paired |
| `DishTheme.cardStroke` | accent @ 12 % | accent @ 12 % | Card borders |

`outline` and `cardStroke` belong to the shared palette and are declared even
where this client draws no divider or card; `ThemeTokenTests` keeps the
shared names whole and does not require them to be drawn.

Fills derived from the palette, named so no view multiplies an alpha itself
("accent" and "error" mean that appearance's own value):

| Token | Dark | Light | Role |
|---|---|---|---|
| `DishTheme.errorDim` | error @ 16 % | error @ 16 % | The tile behind a warning glyph: the session accessory's stopped PC |
| `DishTheme.successFill` | success @ 16 % | success @ 16 % | A BEST or FASTEST chip's ground under its `success` word |
| `DishTheme.primaryFill` | accent @ 14 % | accent @ 14 % | A FAST chip's ground under its `primary` word |

The brand glyphs use the brand book's colour, not the accent:

| Token | Dark | Light | Role |
|---|---|---|---|
| `DishTheme.brandGlyph` | `0x8FCFE3` | `0x2F7E96` | A row glyph's symbol on its tile |

The low-power dim, which must not light the panel:

| Token | Dark | Light | Role |
|---|---|---|---|
| `DishTheme.dimBackground` | `0x000000` | `0x000000` | True black in either appearance, so an OLED panel is off |
| `DishTheme.dimText` | `0x8A8E9E` | `0x8A8E9E` | The dim's words, a grey low enough not to light the panel |

## Type scale (`DishFont`)

Every name is a Dynamic Type style, so the words grow with the person's text
size setting; none is a point size. SF Pro for prose, SF Mono for a PC's name,
an address, a rate or a latency, as the boards draw them. The sizes in the
last column are the styles' defaults at the standard setting.

| Token | Style | Default size | Role |
|---|---|---|---|
| `DishFont.largeTitle` | `.largeTitle`, bold | 34 | A cover's headline and a tab's own large title |
| `DishFont.body` | `.body` | 17 | A row's name |
| `DishFont.headline` | `.headline` | 17 semibold | A row's name with weight, a feature's name on the welcome |
| `DishFont.detail` | `.footnote` | 13 | A row's second line |
| `DishFont.caption` | `.caption` | 12 | A hint under a list |
| `DishFont.mono` | `.body`, monospaced | 17 | A PC's name in a row |
| `DishFont.monoDetail` | `.footnote`, monospaced | 13 | A PC's address, a latency, a rate, the session line |
| `DishFont.feature` | `.title2` | 22 | The glyph in a Local Network primer tile, and a welcome feature's symbol |
| `DishFont.columnTitle` | `.footnote`, semibold | 13 | A column's title over its rows: Sends to PC, Gets back |
| `DishFont.eyebrow` | `.caption`, monospaced, semibold | 12 | A section's eyebrow, drawn upper-cased and tracked |

## Measures (`DishSize`)

Points. Every size a kit component sets is one of these names.

| Token | Value | Role |
|---|---|---|
| `DishSize.rowGlyph` | 40 | The glyph tile at the head of a row |
| `DishSize.rowGlyphCorner` | 10 | The tile's corner |
| `DishSize.rowGlyphSymbol` | 20 | The glyph inside the tile |
| `DishSize.sessionButton` | 44 | The session accessory's round Dim and Play buttons |
| `DishSize.sessionButtonSymbol` | 16 | The glyph inside a session accessory button |
| `DishSize.statusDot` | 8 | The small coloured status dot |
| `DishSize.welcomeMark` | 112 | The brand mark on the welcome |
| `DishSize.featureSymbol` | 32 | A welcome feature's symbol column |
| `DishSize.carryMark` | 16 | The check or dash column of a review carry row |
| `DishSize.primerTile` | 64 | The phone and PC tiles over the Local Network primer |
| `DishSize.eyebrowTracking` | 1.4 | The tracking of a section eyebrow |

## Spacing (`DishSpace`)

| Token | Value |
|---|---|
| `DishSpace.s1` | 2 |
| `DishSpace.s2` | 4 |
| `DishSpace.s3` | 6 |
| `DishSpace.s4` | 8 |
| `DishSpace.s5` | 10 |
| `DishSpace.s6` | 12 |
| `DishSpace.s8` | 16 |
| `DishSpace.s12` | 24 |
| `DishSpace.page` | 16, a page's inset from the screen's edges |

## Symbols (`DishSymbol`)

SF Symbol names the setup chrome draws itself; a row's glyph comes from its
mapper, and the tab bar's from `tabSymbol` in `ShellMappers.swift`.

| Token | Symbol | Role |
|---|---|---|
| `DishSymbol.disclosure` | `chevron.forward` | The trailing chevron of a row that moves on |
| `DishSymbol.back` | `chevron.backward` | The toolbar's Back |
| `DishSymbol.wifi` | `wifi` | Between the phone and the PC over the Local Network primer |
| `DishSymbol.external` | `arrow.up.right` | A link that leaves Dish |
| `DishSymbol.phone` | `iphone` | The phone over the Local Network primer |
| `DishSymbol.pc` | `desktopcomputer` | The PC over the Local Network primer |
| `DishSymbol.linkArrow` | `arrow.down` | From the pad down to the PC on the review card |
| `DishSymbol.add` | `plus` | Add a PC by address |

SF Symbols has no satellite. The antenna, `antenna.radiowaves.left.and.right`
(`satelliteSymbol` in `ShellMappers.swift`), stands in for it on the
Connections tab, the session accessory and a Satellite PC's row, until the
custom glyph is drawn (`Tests/PARITY.md`).

## Images (`DishImage`)

| Token | Asset | Role |
|---|---|---|
| `DishImage.mark` | `DishMark` in `Sources/Dish/Resources/Media.xcassets` | The app mark, version B: the dish tilted 28 degrees, shown on the welcome. Rendered by `scripts/render-icon.sh` from `Resources/Dish.svg`, the fleet's SVG byte for byte, as 1x, 2x and 3x PNGs, since the asset catalog drops the SVG mask that cuts the gear ring. |

## Components

Also in `Theme.swift`:

- `SectionEyebrow(title:color:)`, the tracked, upper-cased monospace eyebrow,
  in the accent to call a section out and muted otherwise.
- `StatusDot(color:)`, the 8 pt dot beside a row's second line.

The kit lives in `Sources/Dish/UI/Kit` and follows the kit rules in
[docs/UI_CONTRACT.md](docs/UI_CONTRACT.md): `Chip` (BEST, FASTEST, FAST),
`RowGlyph` (the rounded tile at the head of a row) and `SessionBar` (the
session accessory).

Words are not design values but follow the same rule: a view reads them from
`L10n` ([Sources/Dish/L10n](Sources/Dish/L10n)), never from a literal, and the
derivations between model and view (a row's text, a dot's colour, an enabled
flag) are pure functions under
[Sources/Dish/UI/Mappers](Sources/Dish/UI/Mappers), tested in
`Tests/DishTests/Mappers`.

## How to use

```swift
import SwiftUI

struct MyRow: View {
    let state: ConnectionRowState

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            RowGlyph(symbol: state.symbol)
            Text(state.name)
                .font(DishFont.mono)
                .foregroundStyle(DishTheme.onSurface)
        }
    }
}
```
