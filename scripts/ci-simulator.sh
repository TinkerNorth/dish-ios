#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  ci-simulator.sh — a simulator CI can trust: created on the newest runtime
#  that supports it, booted, and read back from `simctl list` as Booted
#  before xcodebuild is pointed at it.
#
#  Usage:
#    ci-simulator.sh create <name> <device type prefix>
#        Creates and boots a <name> of the newest device type whose name
#        starts with the prefix, on the newest iOS runtime that lists that
#        type among the ones it supports, and prints its udid once
#        `simctl list` shows it Booted and available.
#    ci-simulator.sh ensure <udid> <name> <device type prefix>
#        Prints <udid> when `simctl list` shows it Booted and available;
#        otherwise says what the list shows, deletes what is left of it and
#        prints the udid of a new one.
#    ci-simulator.sh run <udid> <name> <device type prefix> <command...>
#        Ensures the device, runs the command with the device appended as
#        `-destination "platform=iOS Simulator,id=<udid>"`, and runs it once
#        more, on an ensured device, when it failed because xcodebuild could
#        not find the device or the UI test runner never initialized. A
#        failing test is never run again.
#
#  Why: in ios-ci.yml run 43076579363, attempt 2's `simctl bootstatus -b`
#  returned after 3:22 with no boot stage printed, and a minute later
#  xcodebuild found no simulator at all ("Unable to find a device matching
#  the provided destination specifier", only My Mac listed); attempt 3's
#  iPad was found, and the test runner then "failed to initialize for UI
#  testing" (it timed out loading Accessibility) before any test ran.
# ============================================================================

set -euo pipefail

LOST_DEVICE="Unable to find a device matching the provided destination specifier"
RUNNER_NEVER_STARTED="The test runner failed to initialize for UI testing"

usage() {
    sed -n '4,25p' "$0" >&2
    exit 2
}

# The device's state and availability as `simctl list` reports them, as
# "Booted available"; nothing when the device is not listed.
device_status() {
    xcrun simctl list devices -j | python3 -I -c '
import json, sys
udid = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["udid"] == udid:
            availability = "available" if device["isAvailable"] else "unavailable: " + device.get("availabilityError", "")
            print(device["state"], availability)
' "$1"
}

newest_device_type() {
    xcrun simctl list devicetypes -j | python3 -I -c '
import json, sys
prefix = sys.argv[1]
names = [d["identifier"] for d in json.load(sys.stdin)["devicetypes"] if d["name"].startswith(prefix)]
print(sorted(names)[-1] if names else "")
' "$1"
}

# The newest available iOS runtime that supports the device type: a runtime
# for one iPhone can sit newest on a Mac with several installed.
newest_runtime_for() {
    xcrun simctl list runtimes -j | python3 -I -c '
import json, sys
device_type = sys.argv[1]
runtimes = [
    r for r in json.load(sys.stdin)["runtimes"]
    if r["platform"] == "iOS" and r["isAvailable"]
    and any(d["identifier"] == device_type for d in r.get("supportedDeviceTypes", []))
]
runtimes.sort(key=lambda r: tuple(int(part) for part in r["version"].split(".")))
print(runtimes[-1]["identifier"] if runtimes else "")
' "$1"
}

create() {
    local name="$1" prefix="$2" device_type runtime udid status
    device_type="$(newest_device_type "$prefix")"
    runtime="$(newest_runtime_for "$device_type")"
    [ -n "$device_type" ] && [ -n "$runtime" ] || { echo "no $prefix device type on an available iOS runtime" >&2; exit 1; }
    udid="$(xcrun simctl create "$name" "$device_type" "$runtime")"
    xcrun simctl bootstatus "$udid" -b >&2
    status="$(device_status "$udid")"
    echo "$name $udid after bootstatus: ${status:-not listed}" >&2
    if [ "$status" != "Booted available" ]; then
        xcrun simctl list devices available >&2
        exit 1
    fi
    echo "$udid"
}

ensure() {
    local udid="$1" name="$2" prefix="$3" status
    status="$(device_status "$udid")"
    if [ "$status" = "Booted available" ]; then
        echo "$udid"
        return
    fi
    echo "$name $udid before xcodebuild: ${status:-not listed}; creating another" >&2
    xcrun simctl list devices available >&2
    xcrun simctl delete "$udid" >&2 || true
    create "$name" "$prefix"
}

# The command on the device, its output kept for the retry decision.
run_once() {
    local udid="$1" log="$2"
    shift 2
    "$@" -destination "platform=iOS Simulator,id=$udid" 2>&1 | tee "$log"
}

run() {
    local udid="$1" name="$2" prefix="$3" log status=0
    shift 3
    log="$(mktemp)"
    udid="$(ensure "$udid" "$name" "$prefix")"
    run_once "$udid" "$log" "$@" || status=$?
    [ "$status" -ne 0 ] || return 0
    grep -q -e "$LOST_DEVICE" -e "$RUNNER_NEVER_STARTED" "$log" || exit "$status"
    echo "The runner, not a test, failed; running once more." >&2
    udid="$(ensure "$udid" "$name" "$prefix")"
    run_once "$udid" "$log" "$@"
}

[ $# -ge 1 ] || usage
command="$1"
shift
case "$command" in
    create) [ $# -eq 2 ] || usage; create "$@" ;;
    ensure) [ $# -eq 3 ] || usage; ensure "$@" ;;
    run) [ $# -ge 4 ] || usage; run "$@" ;;
    *) usage ;;
esac
