#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  stage-ipa.sh - stage the unsigned release assets in dist/ from an archive:
#  the versioned IPA that carries the honesty marker, dish-<tag>-unsigned.ipa,
#  and its stable-name copy dish-ios.ipa. release.yml (with the tag) and
#  ios-ci.yml (with the version in VERSION) call it, so the hardening dry run
#  on a pull request signs the files a tag would.
#
#  Usage: stage-ipa.sh <archive path> <tag or version>
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

[ $# -eq 2 ] || { sed -n '4,13p' "$0" >&2; exit 2; }
archive="$1"
tag="$2"

mkdir -p dist
scripts/package-ipa.sh "$archive" "dist/dish-${tag}-unsigned.ipa"
cp "dist/dish-${tag}-unsigned.ipa" dist/dish-ios.ipa
ls -l dist/
