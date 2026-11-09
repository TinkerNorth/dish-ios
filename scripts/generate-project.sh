#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  generate-project.sh — regenerate Dish.xcodeproj from project.yml with
#  the pinned XcodeGen. Run after editing project.yml and commit the result;
#  ios-ci.yml runs it and fails when the committed project differs.
#
#  XcodeGen names the local package reference after the checkout's folder,
#  so the committed project assumes the checkout is called dish-ios, as CI's
#  is; a clone under another name regenerates with a different reference.
#
#  Options:
#    --check   regenerate in place and fail on any difference
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/tools.sh
source scripts/tools.sh

fetch_xcodegen
XCODEGEN="$TOOLS/xcodegen/bin/xcodegen"

if [ "${1:-}" = "--check" ]; then
    # The project must be generated in place: the package reference inside it
    # is relative to where the project sits. The committed copy is set aside,
    # compared with a fresh one, and put back if they differ.
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' EXIT
    cp -R Dish.xcodeproj "$scratch/Dish.xcodeproj"
    "$XCODEGEN" generate --quiet --spec project.yml --project .
    if ! diff -r -x xcuserdata -x project.xcworkspace "$scratch/Dish.xcodeproj" Dish.xcodeproj; then
        rm -rf Dish.xcodeproj
        cp -R "$scratch/Dish.xcodeproj" Dish.xcodeproj
        echo "Dish.xcodeproj is not what project.yml generates; run scripts/generate-project.sh and commit" >&2
        if [ "$(basename "$PWD")" != "dish-ios" ]; then
            echo "note: the checkout is named $(basename "$PWD"), and the package reference carries the folder's name" >&2
        fi
        exit 1
    fi
    echo "Dish.xcodeproj matches project.yml"
    exit 0
fi

"$XCODEGEN" generate --quiet --spec project.yml --project .
echo "Generated Dish.xcodeproj"
