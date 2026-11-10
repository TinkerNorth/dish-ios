#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  ci-local.sh — run the iOS CI gates against this worktree, in CI's order.
#
#  A green run here is a green `ios-ci.yml` run: the same pinned SwiftFormat,
#  SwiftLint and XcodeGen release binaries (scripts/tools.sh downloads them
#  once into .build/tools and verifies the SHA-256), then the project drift
#  check, `xcodebuild test` on an iPhone simulator, the UI tests again on an
#  iPad simulator, and the Release build.
#
#  Options:
#    --quick     skip the Release build
#    --no-tests  build the tests but do not run them
#
#  Environment:
#    DISH_SIM_DESTINATION   the xcodebuild test destination; default
#                           "platform=iOS Simulator,name=iPhone 17 Pro". Pin an
#                           OS when several runtimes are installed, e.g.
#                           "platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro".
#    DISH_IPAD_DESTINATION  the iPad the UI tests run on again; default
#                           "platform=iOS Simulator,name=iPad Pro 11-inch (M5)".
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/tools.sh
source scripts/tools.sh

QUICK=0
RUN_TESTS=1
for arg in "$@"; do
    case "$arg" in
        --quick) QUICK=1 ;;
        --no-tests) RUN_TESTS=0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

DESTINATION="${DISH_SIM_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
IPAD_DESTINATION="${DISH_IPAD_DESTINATION:-platform=iOS Simulator,name=iPad Pro 11-inch (M5)}"

fetch_swiftformat
fetch_swiftlint
fetch_xcodegen

tools_log "swiftformat --lint"
"$TOOLS/swiftformat" --lint .

tools_log "swiftlint --strict"
"$TOOLS/swiftlint" lint --strict --quiet

tools_log "Dish.xcodeproj matches project.yml"
scripts/generate-project.sh --check

if [ "$RUN_TESTS" -eq 1 ]; then
    tools_log "xcodebuild test ($DESTINATION)"
    xcodebuild test \
        -project Dish.xcodeproj \
        -scheme DishApp \
        -destination "$DESTINATION" \
        -enableCodeCoverage YES \
        -quiet \
        CODE_SIGNING_ALLOWED=NO

    tools_log "xcodebuild test, the UI tests on an iPad ($IPAD_DESTINATION)"
    xcodebuild test \
        -project Dish.xcodeproj \
        -scheme DishApp \
        -destination "$IPAD_DESTINATION" \
        -only-testing:DishUITests \
        -enableCodeCoverage YES \
        -quiet \
        CODE_SIGNING_ALLOWED=NO
else
    tools_log "xcodebuild build-for-testing ($DESTINATION)"
    xcodebuild build-for-testing \
        -project Dish.xcodeproj \
        -scheme DishApp \
        -destination "$DESTINATION" \
        -quiet \
        CODE_SIGNING_ALLOWED=NO
fi

if [ "$QUICK" -eq 0 ]; then
    tools_log "xcodebuild build (Release, simulator)"
    xcodebuild build \
        -project Dish.xcodeproj \
        -scheme DishApp \
        -configuration Release \
        -destination "generic/platform=iOS Simulator" \
        -quiet \
        CODE_SIGNING_ALLOWED=NO
fi

tools_log "all gates passed"
