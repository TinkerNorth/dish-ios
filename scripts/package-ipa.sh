#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  package-ipa.sh — zip the Dish.app of an unsigned archive into an IPA (a
#  zip whose Payload/ holds the .app). Used by release.yml for the unsigned
#  release and by ios-ci.yml's device-archive lane, so the packaging is
#  proven before a tag.
#
#  Usage: package-ipa.sh <archive path> <output .ipa>
# ============================================================================

set -euo pipefail

[ $# -eq 2 ] || { sed -n '4,11p' "$0" >&2; exit 2; }
archive="$1"
output="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"

payload="$(mktemp -d)"
trap 'rm -rf "$payload"' EXIT
mkdir -p "$payload/Payload"
cp -R "$archive/Products/Applications/Dish.app" "$payload/Payload/"
rm -f "$output"
(cd "$payload" && zip -qry "$output" Payload)
listing="$(unzip -l "$output")"
grep -q 'Payload/Dish.app/Info.plist' <<<"$listing" || { echo "$output has no Payload/Dish.app" >&2; exit 1; }
echo "$output"
