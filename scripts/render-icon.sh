#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Render the app icon from Sources/Dish/Resources/Media.xcassets/DishMark.imageset/dish-logo.svg,
# the app mark the fleet shares (dish-linux resources/brand/dish-logo.svg,
# byte for byte). The SVG is the source; the 1024 px PNG is a build product
# kept in the tree because the asset catalog wants a raster icon. iOS draws
# the mark on the brand's deep-space ground with the margin the icon grid
# leaves. Run after the mark changes.
#
# Requires rsvg-convert (Homebrew librsvg).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="${ROOT}/Sources/Dish/Resources/Media.xcassets/DishMark.imageset/dish-logo.svg"
PNG="${ROOT}/App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

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
