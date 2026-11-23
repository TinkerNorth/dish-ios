#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  tools.sh — the one place a toolchain pin lives: the Xcode the apple jobs
#  select and the release binaries the gates run with, fetched once into
#  .build/tools and verified by SHA-256. Sourced by ci-local.sh, the gate
#  scripts (check-format.sh, check-lint.sh, generate-project.sh) and, through
#  them, every workflow. A bump is a deliberate commit that reformats or
#  regenerates the tree with it, here and in THIRD_PARTY.md and CONTRIBUTING.md,
#  which ToolPinTests keeps equal to this file.
# ============================================================================

# The Xcode the macos-26 image carries and CI selects by this version
# (scripts/select-xcode.sh), so an image update cannot change the toolchain.
XCODE_VERSION="26.6"
SWIFTFORMAT_VERSION="0.64.7"
SWIFTFORMAT_SHA256="e82e224325cbd3403fc7b68caf6c917926dc106de3af875fca4b87e3c4634038"
SWIFTLINT_VERSION="0.65.1"
SWIFTLINT_SHA256="c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"
XCODEGEN_VERSION="2.48.0"
XCODEGEN_SHA256="620c9f0dc10849f94728ab5df52d225ebab8187439dd6fee1925e59e80dff892"

TOOLS="${TOOLS:-.build/tools}"

tools_log() { printf '\n== %s ==\n' "$*"; }

# fetch_pinned <binary path inside the zip> <url> <sha256>
# Skips the download when the binary is present and was unpacked from this digest.
fetch_pinned() {
    local binary="$1" url="$2" sha="$3"
    local name zip
    name="$(basename "$binary")"
    zip="$TOOLS/$name.zip"
    if [ -x "$TOOLS/$binary" ] && [ "$(cat "$TOOLS/$name.version" 2>/dev/null)" = "$sha" ]; then
        return
    fi
    tools_log "fetching $name $url"
    mkdir -p "$TOOLS"
    curl -fsSL --retry 3 -o "$zip" "$url"
    echo "$sha  $zip" | shasum -a 256 -c -
    unzip -q -o "$zip" -d "$TOOLS"
    chmod +x "$TOOLS/$binary"
    echo "$sha" > "$TOOLS/$name.version"
}

fetch_swiftformat() {
    fetch_pinned swiftformat \
        "https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFTFORMAT_VERSION}/swiftformat.zip" \
        "$SWIFTFORMAT_SHA256"
}

fetch_swiftlint() {
    fetch_pinned swiftlint \
        "https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/portable_swiftlint.zip" \
        "$SWIFTLINT_SHA256"
}

fetch_xcodegen() {
    fetch_pinned xcodegen/bin/xcodegen \
        "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip" \
        "$XCODEGEN_SHA256"
}
