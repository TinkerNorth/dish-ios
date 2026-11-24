#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# ============================================================================
#  write-sbom.sh - the SPDX bill of materials of what Dish.app carries,
#  dish-ios-components.spdx.json.
#
#  Syft, which the release hardening runs over the release directory, does not
#  look inside the IPA and names nothing in it. This document is written from
#  the tree the build used instead (Package.swift declares no package
#  dependency, so nothing is resolved):
#
#    * ENet, ported to Swift from the cgutman fork, and SDL's Steam Controller
#      Bluetooth protocols, ported by way of dish-mac, each at the full commit
#      THIRD_PARTY.md names (no C is compiled, but the protocol logic is
#      theirs);
#    * the controller database the app bundles, at the dbVersion its manifest
#      names.
#
#  It then checks itself against THIRD_PARTY.md: every component the summary
#  says reaches the user, that is every row not marked "Not in the app", must
#  be in the document, or the script fails. stage-ipa.sh writes it into dist/
#  beside the IPA, as release.yml does on a signed tag, so ios-ci.yml's dry run
#  and the tag both hand it to _release_harden.yml, whose Syft folds it into
#  the product SBOM and whose Grype scans it. ToolPinTests pins the callers
#  and the components named here.
#
#  Usage: scripts/write-sbom.sh <out.spdx.json> [version]
# ============================================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="${1:?usage: write-sbom.sh <out.spdx.json> [version]}"
VERSION="${2:-$(tr -d '[:space:]' < VERSION)}"

python3 -I - "$OUT" "$VERSION" <<'PY'
import datetime
import json
import re
import sys
import uuid

out, version = sys.argv[1], sys.argv[2]

with open("THIRD_PARTY.md", encoding="utf-8") as handle:
    notice = handle.read()

packages = []


def add(name, package_version, licence, download, purl=None, comment=None):
    package = {
        "name": name,
        "SPDXID": "SPDXRef-Package-" + re.sub(r"[^A-Za-z0-9.-]", "-", name),
        "versionInfo": package_version,
        "downloadLocation": download,
        "filesAnalyzed": False,
        "licenseConcluded": licence,
        "licenseDeclared": licence,
        "copyrightText": "NOASSERTION",
    }
    if purl:
        package["externalRefs"] = [
            {"referenceCategory": "PACKAGE-MANAGER", "referenceType": "purl", "referenceLocator": purl}
        ]
    if comment:
        package["comment"] = comment
    packages.append(package)


def commit_named(pattern, what):
    match = re.search(pattern, notice)
    if not match:
        sys.exit(f"THIRD_PARTY.md names no full commit for {what}")
    return match.group(1)


# ENet: the commit THIRD_PARTY.md section 2c names.
enet = commit_named(r"https://github\.com/cgutman/enet>,\s*`([0-9a-f]{40})`", "ENet (section 2c)")
add(
    "enet",
    enet,
    "MIT",
    f"git+https://github.com/cgutman/enet@{enet}",
    purl=f"pkg:github/cgutman/enet@{enet}",
    comment="The client subset of its reliable-UDP protocol, ported to Swift under Sources/DishCore/Moonlight/Enet/; no C is compiled.",
)

# SDL: the commit THIRD_PARTY.md section 2d names.
sdl = commit_named(r"https://github\.com/libsdl-org/SDL>\s+at\s+`([0-9a-f]{40})`", "SDL (section 2d)")
add(
    "sdl",
    sdl,
    "Zlib",
    f"git+https://github.com/libsdl-org/SDL@{sdl}",
    purl=f"pkg:github/libsdl-org/SDL@{sdl}",
    comment="The Steam Controllers' Bluetooth LE protocols, ported to Swift under Sources/DishCore/DirectInput/ by way of dish-mac; no C is compiled.",
)

# The controller database the app bundles.
with open("Sources/DishCore/Resources/controllers-v1/manifest.json", encoding="utf-8") as handle:
    manifest = json.load(handle)
add(
    "dish-controller-database",
    str(manifest["dbVersion"]),
    "NOASSERTION",
    "https://dish.tinkernorth.com/controllers/v1/",
    comment=f"TinkerNorth's controller list, published {manifest['publishedAt']}, bundled byte for byte with its manifest.",
)

# Every component the summary's first table says reaches the user is named.
summary = notice.split("## 1. Summary", 1)[1].split("\n#", 1)[0]
named = {package["name"] for package in packages}
for line in summary.splitlines():
    if not line.startswith("| [") or "Not in the app" in line:
        continue
    component = line[3:line.index("]")]
    if component.lower() not in named:
        sys.exit(f"THIRD_PARTY.md says {component} reaches the user: write-sbom.sh must name it")

root = "SPDXRef-Package-dish-ios"
relationships = [{"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": root}]
relationships += [
    {"spdxElementId": root, "relationshipType": "CONTAINS", "relatedSpdxElement": package["SPDXID"]}
    for package in packages
]
document = {
    "spdxVersion": "SPDX-2.3",
    "dataLicense": "CC0-1.0",
    "SPDXID": "SPDXRef-DOCUMENT",
    "name": f"dish-ios-{version}-components",
    "documentNamespace": f"https://github.com/TinkerNorth/dish-ios/sbom/{version}/{uuid.uuid4()}",
    "creationInfo": {
        "created": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "creators": ["Organization: TinkerNorth", "Tool: dish-ios-scripts/write-sbom.sh"],
    },
    "packages": [
        {
            "name": "dish-ios",
            "SPDXID": root,
            "versionInfo": version,
            "downloadLocation": "https://github.com/TinkerNorth/dish-ios",
            "filesAnalyzed": False,
            "licenseConcluded": "LGPL-3.0-or-later",
            "licenseDeclared": "LGPL-3.0-or-later",
            "copyrightText": "Copyright (C) 2026 Dish contributors.",
        }
    ]
    + packages,
    "relationships": relationships,
}
with open(out, "w", encoding="utf-8") as handle:
    json.dump(document, handle, indent=2)
    handle.write("\n")
print(f"Wrote {out}: {len(packages)} components of dish-ios {version}")
PY
