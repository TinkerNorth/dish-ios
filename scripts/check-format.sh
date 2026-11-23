#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  check-format.sh — SwiftFormat in lint mode with the pinned release binary.
#  Called by ci-local.sh and by ios-ci.yml.
# ============================================================================

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/tools.sh
source scripts/tools.sh
fetch_swiftformat

# A rule that times out on a loaded runner is not a finding, so the lint runs
# once more then; any other failure stands.
if ! output="$("$TOOLS/swiftformat" --lint . 2>&1)"; then
    echo "$output"
    grep -q "rule timed out" <<<"$output" || exit 1
    echo "A rule timed out on a slow machine; linting once more."
    "$TOOLS/swiftformat" --lint .
fi
echo "$output"
