#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Render the app icon and the in-app mark from Resources/Dish.svg, the app
# mark the fleet shares (dish-linux resources/brand/dish-logo.svg, byte for
# byte). The SVG is the source; the 1024 px PNG icon and the mark's 1x, 2x
# and 3x PNGs are build products kept in the tree: the asset catalog wants a
# raster icon, and neither its SVG import nor CoreGraphics' PDF drawing keeps
# the mask that cuts the gear ring, so the mark ships as pixels rendered by
# librsvg, which does. iOS draws the icon on the brand's deep-space ground
# with the margin the icon grid leaves. Run after the mark changes.
#
# Requires rsvg-convert (Homebrew librsvg).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="${ROOT}/Resources/Dish.svg"
PNG="${ROOT}/App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
MARKS="${ROOT}/Sources/Dish/Resources/Media.xcassets/DishMark.imageset"

command -v rsvg-convert >/dev/null || { echo "rsvg-convert is missing: brew install librsvg" >&2; exit 1; }

# A 1024 px canvas, the mark at 72 % of it, centred.
canvas=1024
mark=736
inset=$(( (canvas - mark) / 2 ))
rsvg-convert \
  --width "${mark}" --height "${mark}" --keep-aspect-ratio \
  --page-width "${canvas}" --page-height "${canvas}" \
  --left "${inset}" --top "${inset}" \
  --background-color '#060818' \
  "${SVG}" -o "${PNG}"
echo "Rendered ${PNG} from ${SVG}"

# The mark at 160 pt, the largest any page draws it, in the three scales.
for scale in 1 2 3; do
  suffix=""
  [ "${scale}" -gt 1 ] && suffix="@${scale}x"
  rsvg-convert --width $(( 160 * scale )) --height $(( 160 * scale )) --keep-aspect-ratio \
    "${SVG}" -o "${MARKS}/DishMark${suffix}.png"
done
echo "Rendered ${MARKS}/DishMark{,@2x,@3x}.png from ${SVG}"
