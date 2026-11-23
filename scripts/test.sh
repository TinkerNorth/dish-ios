#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  test.sh — one xcodebuild test run on a simulator this script creates,
#  boots and deletes (scripts/ci-simulator.sh). Called by ci-local.sh and by
#  ios-ci.yml.
#
#  Usage: test.sh <suite>
#    iphone      every test target of the DishApp scheme on an iPhone 17 Pro
#    ipad        the UI tests again on an iPad Pro 11-inch, where the tabs
#                open into a sidebar and the windows turn with the device
#    lock-stats  the lock-law and tracked-lock tests with LOCK_STATS compiled
#                in, on an iPhone
#
#  Environment:
#    DISH_SIM_DESTINATION   run the iphone and lock-stats suites on this
#                           xcodebuild destination instead of creating a
#                           simulator, e.g.
#                           "platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro".
#    DISH_IPAD_DESTINATION  the same for the ipad suite.
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

[ $# -eq 1 ] || { sed -n '4,22p' "$0" >&2; exit 2; }
suite="$1"

quiet=()
[ -n "${GITHUB_ACTIONS:-}" ] || quiet=(-quiet)

case "$suite" in
    iphone)
        name="CI iPhone"; prefix="iPhone 17 Pro"; override="${DISH_SIM_DESTINATION:-}"
        extra=(-enableCodeCoverage YES)
        ;;
    ipad)
        name="CI iPad"; prefix="iPad Pro 11-inch"; override="${DISH_IPAD_DESTINATION:-}"
        extra=(-only-testing:DishUITests -enableCodeCoverage YES)
        ;;
    lock-stats)
        name="CI iPhone"; prefix="iPhone 17 Pro"; override="${DISH_SIM_DESTINATION:-}"
        extra=(
            -only-testing:DishEngineTests/LockLawTests
            -only-testing:DishEngineTests/TrackedLockTests
        )
        ;;
    *) sed -n '4,22p' "$0" >&2; exit 2 ;;
esac

command=(
    xcodebuild test
    -project Dish.xcodeproj
    -scheme DishApp
    ${extra[@]+"${extra[@]}"}
    ${quiet[@]+"${quiet[@]}"}
    CODE_SIGNING_ALLOWED=NO
)
[ "$suite" != "lock-stats" ] || command+=('SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) LOCK_STATS')

printf '\n== xcodebuild test (%s) ==\n' "$suite"
if [ -n "$override" ]; then
    "${command[@]}" -destination "$override"
    exit 0
fi

udid="$(scripts/ci-simulator.sh create "$name" "$prefix")"
trap 'xcrun simctl delete "$udid" >/dev/null 2>&1 || true' EXIT
scripts/ci-simulator.sh run "$udid" "$name" "$prefix" "${command[@]}"
