#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  check-lint.sh — SwiftLint --strict with the pinned release binary. Called
#  by ci-local.sh and by ios-ci.yml; under GitHub Actions the findings are
#  annotations on the diff.
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/tools.sh
source scripts/tools.sh
fetch_swiftlint

if [ -n "${GITHUB_ACTIONS:-}" ]; then
    "$TOOLS/swiftlint" lint --strict --reporter github-actions-logging
else
    "$TOOLS/swiftlint" lint --strict --quiet
fi
