#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  build-release.sh — the Release build of the app for the simulator, into
#  build/ (Dish.app lands in build/Build/Products/Release-iphonesimulator).
#  Called by ci-local.sh and by ios-ci.yml, which uploads the .app.
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

quiet=()
[ -n "${GITHUB_ACTIONS:-}" ] || quiet=(-quiet)

xcodebuild build \
    -project Dish.xcodeproj \
    -scheme DishApp \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath build \
    ${quiet[@]+"${quiet[@]}"} \
    CODE_SIGNING_ALLOWED=NO
