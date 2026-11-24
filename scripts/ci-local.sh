#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  ci-local.sh - run the iOS CI gates against this worktree, in CI's order.
#
#  A green run here is a green `ios-ci.yml` run: both call the same scripts
#  (check-format.sh, check-lint.sh, generate-project.sh, test.sh,
#  build-release.sh, archive-device.sh), which use the pinned SwiftFormat,
#  SwiftLint and XcodeGen release binaries that scripts/tools.sh downloads
#  once into .build/tools and verifies by SHA-256. A tool that cannot be
#  fetched or a simulator that cannot be created fails the run; nothing is
#  skipped quietly.
#
#  The gates, in order:
#    security      the action-pin lint, the vulnerability allowlist,
#                  OSV-Scanner and gitleaks, at the versions tools.sh pins
#    format        swiftformat --lint
#    lint          swiftlint --strict
#    project       Dish.xcodeproj matches project.yml
#    test          every test target on an iPhone simulator, then the UI
#                  tests again on an iPad simulator
#    release       the Release build for the simulator
#    archive       the unsigned archive for a generic iOS device, packaged as
#                  an IPA the way release.yml packages the unsigned release,
#                  with its components SBOM (write-sbom.sh)
#
#  Options:
#    --quick           skip the release and archive gates
#    --no-tests        build the tests but do not run them
#    --with-lock-stats also run the LOCK_STATS tests (CI's second job)
#    --with-e2e        also run scripts/e2e_local.sh against the real satellite
#                      (needs cmake, libsodium, opus and a logged-in GUI session)
#
#  Run only by CI, with the reason:
#    - select-xcode.sh: a runner picks its Xcode by the version in tools.sh;
#      this script reports when your selected Xcode is another version.
#    - version-consistency.yml: a text gate; VersionConsistencyTests runs the
#      same checks in the test gate here.
#    - dependency review (it reads GitHub's view of the pull request),
#      codeql.yml (the code scanning upload) and the release-hardening dry
#      run (a Linux job: Grype, Syft and cosign of the PR-built IPA).
#    - e2e.yml: the same e2e_local.sh as --with-e2e, on a runner.
#    - release.yml: the signed archive, the export and the App Store Connect
#      upload need the six signing secrets; the rest needs a tag.
#
#  Environment:
#    DISH_SIM_DESTINATION   run the iPhone gates on this xcodebuild destination
#                           instead of a simulator the script creates, e.g.
#                           "platform=iOS Simulator,OS=26.5,name=iPhone 17 Pro".
#    DISH_IPAD_DESTINATION  the same for the iPad gate.
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/tools.sh
source scripts/tools.sh

QUICK=0
RUN_TESTS=1
WITH_LOCK_STATS=0
WITH_E2E=0
for arg in "$@"; do
    case "$arg" in
        --quick) QUICK=1 ;;
        --no-tests) RUN_TESTS=0 ;;
        --with-lock-stats) WITH_LOCK_STATS=1 ;;
        --with-e2e) WITH_E2E=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

selected="$(xcodebuild -version | sed -n '1s/^Xcode //p')"
if [ "${selected%.0}" != "$XCODE_VERSION" ]; then
    echo "note: Xcode $selected is selected; CI pins $XCODE_VERSION (scripts/tools.sh). Trust CI for the pinned toolchain."
fi

tools_log "security gates"
scripts/check-security.sh

tools_log "swiftformat --lint"
scripts/check-format.sh

tools_log "swiftlint --strict"
scripts/check-lint.sh

tools_log "Dish.xcodeproj matches project.yml"
scripts/generate-project.sh --check

if [ "$RUN_TESTS" -eq 1 ]; then
    scripts/test.sh iphone
    scripts/test.sh ipad
    if [ "$WITH_LOCK_STATS" -eq 1 ]; then
        scripts/test.sh lock-stats
    fi
else
    tools_log "xcodebuild build-for-testing"
    xcodebuild build-for-testing \
        -project Dish.xcodeproj \
        -scheme DishApp \
        -destination "generic/platform=iOS Simulator" \
        -quiet \
        CODE_SIGNING_ALLOWED=NO
fi

if [ "$QUICK" -eq 0 ]; then
    tools_log "xcodebuild build (Release, simulator)"
    scripts/build-release.sh

    tools_log "xcodebuild archive (generic iOS device, unsigned) and the IPA"
    archive="${TMPDIR:-/tmp}/dish-ci-local.xcarchive"
    scripts/archive-device.sh "$archive" CODE_SIGNING_ALLOWED=NO
    scripts/stage-ipa.sh "$archive" "$(tr -d '[:space:]' < VERSION)"
    rm -rf "$archive" dist
fi

if [ "$WITH_E2E" -eq 1 ]; then
    tools_log "e2e against the real satellite"
    bash scripts/e2e_local.sh
fi

tools_log "all gates passed"
