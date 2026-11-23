#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  select-xcode.sh — select the Xcode pinned in scripts/tools.sh
#  (XCODE_VERSION) on a CI runner, by version and not by the image's
#  /Applications/Xcode.app link, which moves when the image's default does.
#  CI only: a developer's Mac keeps its own selection, and ci-local.sh says
#  when it differs from the pin.
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/tools.sh
source scripts/tools.sh

app="/Applications/Xcode_${XCODE_VERSION}.app"
if [ ! -d "$app" ]; then
    echo "::error::$app is not on this image; the pinned Xcode is ${XCODE_VERSION}" >&2
    ls -d /Applications/Xcode*.app >&2 || true
    exit 1
fi
sudo xcode-select -s "$app"
xcodebuild -version
