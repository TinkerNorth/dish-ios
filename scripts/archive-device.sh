#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  archive-device.sh — archive the app for a generic iOS device, the build
#  release.yml ships, and check what it made: Dish.app is in the archive,
#  carries an arm64 slice and reports the version in VERSION.
#
#  Usage: archive-device.sh <archive path> [build setting ...]
#
#  Every further argument goes to xcodebuild as is. A pull request's lane
#  passes CODE_SIGNING_ALLOWED=NO, so a compile or link error only a device
#  build raises shows there and not first at the tag; release.yml passes the
#  build number and, for a signed build, the manual signing settings.
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

[ $# -ge 1 ] || { sed -n '4,16p' "$0" >&2; exit 2; }
archive="$1"
shift

quiet=()
[ -n "${GITHUB_ACTIONS:-}" ] || quiet=(-quiet)

rm -rf "$archive"
xcodebuild archive \
    -project Dish.xcodeproj \
    -scheme DishApp \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$archive" \
    ${quiet[@]+"${quiet[@]}"} \
    "$@"

app="$archive/Products/Applications/Dish.app"
[ -d "$app" ] || { echo "no Dish.app in $archive" >&2; exit 1; }
archs="$(lipo -archs "$app/Dish")"
case " $archs " in *" arm64 "*) ;; *) echo "Dish.app has no arm64 slice (got: $archs)" >&2; exit 1 ;; esac
reported="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Info.plist")"
version="$(tr -d '[:space:]' < VERSION)"
[ "$reported" = "$version" ] || { echo "Dish.app reports $reported but VERSION is $version" >&2; exit 1; }
echo "Dish.app $reported ($archs) archived at $archive"
