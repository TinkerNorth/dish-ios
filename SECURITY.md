# Security policy: TinkerNorth

This file covers the six TinkerNorth repositories that ship the
wireless-gamepad product end-to-end:

- [`satellite`](https://github.com/TinkerNorth/satellite): server (Windows / Linux / macOS)
- [`dish-android`](https://github.com/TinkerNorth/dish-android): Android client
- [`dish-windows`](https://github.com/TinkerNorth/dish-windows): Windows client (Qt6 / SDL2)
- [`dish-linux`](https://github.com/TinkerNorth/dish-linux): Linux client (Qt6 / SDL2)
- [`dish-mac`](https://github.com/TinkerNorth/dish-mac): macOS client (SwiftUI)
- [`dish-ios`](https://github.com/TinkerNorth/dish-ios): iPhone and iPad client (SwiftUI)

Each repo has its own `CONTRIBUTING.md#security` section with
ecosystem-specific local commands; this file is the single source of
truth for **(1) reporting a vulnerability**, **(2) what we do with the
report**, and **(3) how a downstream consumer verifies a release
artifact**.

---

## Reporting a vulnerability

**Do not file a public issue for a suspected vulnerability.**

Use one of:

1. **GitHub private vulnerability reporting**: open the repo, click
   *Security → Report a vulnerability*. This is preferred because it
   creates a tracked advisory and a private discussion thread.
2. **Email**: `security@tinkernorth.com` (PGP key on request).
   Include the repo, version (commit SHA or release tag), reproduction
   steps, and impact.

Please do **not** test exploits against infrastructure you don't own.
The on-LAN threat model already covers an attacker with packet-injection
ability on the local network, that's the documented design boundary,
not a bug.

### Response SLA

| Severity | Triage acknowledgement | Initial assessment | Fix target |
|---|---|---|---|
| Critical (CVSS >= 9.0) | 1 business day | 3 business days | 14 days, coordinated disclosure |
| High (CVSS 7.0–8.9)    | 2 business days | 5 business days | 30 days |
| Medium / Low           | 5 business days | 10 business days | next minor release |

If we miss the SLA, you may publish 90 days after the original report
date regardless. We'd rather know than not know.

### Scope

In scope:

- All six repos above.
- Release artifacts attached to GitHub Releases for any of the six repos.
- The wire protocol (protocol 4, which clients still speak down to 1; the single source of truth is
  [`satellite/docs/contract.md`](https://github.com/TinkerNorth/satellite/blob/main/docs/contract.md)):
  the HTTPS `:9443` control plane (TOFU-pinned self-signed TLS, HMAC
  proof-of-key headers, declarative session PUT) and the UDP `:9876` data
  plane (ChaCha20-Poly1305-IETF under per-session HKDF keys, per-direction
  counters, replay guard).
- The pairing flow (PIN paths A/B on `:9443`) + the loopback-only admin
  HTTP/SSE web UI exposed by `satellite`.

Out of scope:

- Anything that requires the attacker to already have local privileges
  on the user's PC (root, Administrator, ability to drop binaries in
  `%APPDATA%`, etc.).
- The vendored ViGEmBus driver itself: file with [nefarius/ViGEmBus](https://github.com/nefarius/ViGEmBus).
- DoS via raw network flooding: UDP without rate-limit is a known
  trade-off for hot-path latency; mitigations belong in the network
  fabric, not the protocol.

---

## Supported versions

| Repo | Supported | Notes |
|---|---|---|
| `satellite` | latest minor on `main`; previous minor for 90 days | Windows is the canonical target; Linux is supported; macOS virtual pads require the virtual-HID entitlement (unentitled builds fall back to an inert backend) |
| `dish-android` | latest minor on `main`; previous minor for 90 days | minSdk 24 |
| `dish-windows` | latest minor on `main`; previous minor for 90 days | 64-bit Windows 10 (1809 or newer) and Windows 11 |
| `dish-linux` | latest minor on `main`; previous minor for 90 days | tracks the oldest LTS the release CI builds against |
| `dish-mac` | latest minor on `main`; previous minor for 90 days | macOS 13+ |
| `dish-ios` | latest minor on `main`; previous minor for 90 days | iOS 26.0+ on iPhone and iPad; the app speaks the whole wire protocol (pairing, the encrypted session, Moonlight hosts), so the scope above covers it |

Patch releases (`X.Y.Z+1`) are issued on demand for the latest minor;
the previous minor only receives backports for high/critical fixes.

---

## How CI prevents vulnerable code from shipping

Each repo runs the same shape of gates:

**On every PR** (blocking):

- Action-pin lint: every `uses:` line must reference a 40-char SHA followed
  by a `# vX.Y.Z` comment (`scripts/check-action-pins.sh`).
- Allowlist gate: `.security/allowlist.yaml` is the only place a
  vulnerability is accepted; an entry past `expires`, or more than 90 days out,
  fails.
- Dependency review: GitHub advisory DB (PR-only).
- OSV-Scanner: vendored components and manifest dependencies;
  ecosystem-specific scope (see each repo's `security.yml`).
- Gitleaks: secret scanning over the git history.
- CodeQL: `cpp` for `satellite` / `dish-linux`, `swift` for `dish-mac` and `dish-ios`,
  `java-kotlin` + `cpp` for `dish-android`.
- Release hardening, as a dry run: the steps below that follow a tag, run on
  the pull request's own build with a throwaway key and nothing published.

**On every tagged release** (also blocking):

- Re-run of every PR-time gate against the tagged commit.
- Required-secrets gate: refuses to publish if the platform signing
  secret is missing for a tag (Windows Authenticode, Apple Developer ID
  + notarization, Android keystore). For `dish-ios` the gate is advisory
  by default: without the six App Store secrets named in `release.yml`
  the tag ships an unsigned IPA, with a warning, unless the repository
  variable `ENFORCE_RELEASE_SIGNING` is `true`.
- Artifact-level vulnerability scan: Anchore Grype (a pinned binary), fails on
  CRITICAL/HIGH.
- SBOM generation: Syft (a pinned binary), both SPDX-JSON and CycloneDX-JSON.
- `SHA256SUMS` over every artifact and the SBOMs.
- Cosign keyless signing: every file and `SHA256SUMS` get a
  `<file>.sigstore.json` bundle, anchored in the Sigstore transparency log. The
  signing run must be on the tag ref: a tag push, or
  `gh workflow run release.yml --ref X.Y.Z -f tag=X.Y.Z`.
- SLSA L3 build provenance: `slsa-framework/slsa-github-generator`
  emits `<repo>.intoto.jsonl`.

The result: a known-vulnerable dep, a missing signature, or a tampered
binary all fail the release before any artifact lands on the GitHub
Release page.

---

## Verifying a release artifact (consumer recipe)

No `dish-ios` release has been published yet, so none of these commands has been run against one.

This recipe works the same way for every release, every repo, every
platform; only the artifact filenames change. Each file carries one Sigstore
bundle, `<file>.sigstore.json`. The tag is bare `X.Y.Z` in every command.

### 0) Pre-requisites

```bash
# cosign 3.x: brew install cosign, or a release binary from
# github.com/sigstore/cosign/releases (check it against cosign_checksums.txt)
```

### 1) Download every file from the Release

```bash
TAG=X.Y.Z
REPO=dish-ios   # or satellite, dish-android, dish-mac, dish-windows, dish-linux
gh release download "$TAG" -R "TinkerNorth/$REPO" -D "$REPO-$TAG"
cd "$REPO-$TAG"
```

You should see the platform artifacts (for `dish-ios`: `dish-X.Y.Z-unsigned.ipa`
and the stable `dish-ios.ipa`, or the dSYMs when the build went to App Store
Connect), `dish-ios-components.spdx.json` (what the app carries, which the
product SBOM folds in, since Syft does not look inside an IPA), `SHA256SUMS`
with its bundle, `<product>.sbom.spdx.json` and `<product>.sbom.cdx.json`, and
`<product>.intoto.jsonl` (the SLSA L3 provenance).

### 2) One bundle per file

```bash
# SHA256SUMS was signed by this repository's release workflow, on this tag.
cosign verify-blob \
  --bundle SHA256SUMS.sigstore.json \
  --certificate-identity "https://github.com/TinkerNorth/$REPO/.github/workflows/_release_harden.yml@refs/tags/$TAG" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  SHA256SUMS

# Every file you downloaded matches it (macOS: shasum -a 256 -c).
sha256sum --ignore-missing -c SHA256SUMS
```

The identity is exact, not a regular expression, and names
`_release_harden.yml` because the certificate's identity is the workflow that
ran the signing step. To verify one file on its own, run the same
`cosign verify-blob` with `--bundle <file>.sigstore.json` and `<file>`.

### 3) The SLSA L3 provenance

`<product>.intoto.jsonl` is a Sigstore bundle whose statement names every
released file by SHA-256. It is signed by the SLSA generator at the exact
commit the workflow pins, which `slsa-verifier` refuses ("invalid ref") because
that is not a release tag, so verify it with cosign, naming the generator's
commit from the provenance's `builder.id`:

```bash
cosign verify-blob-attestation \
  --bundle "dish-ios.intoto.jsonl" --type slsaprovenance \
  --certificate-identity "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@f7dd8c54c2067bafc12ca7a55595d5ee9b75204a" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  dish-X.Y.Z-unsigned.ipa
```

(The commit is the generator v2.1.0 that `release.yml` pins; use the one in
the provenance you are checking.)

### 4) (Optional) Inspect the SBOM

```bash
jq -S . dish-ios.sbom.spdx.json | less
```

---

## Known gaps

- **The iOS release may be unsigned.** Until the six App Store secrets
  exist, `dish-ios` publishes `dish-X.Y.Z-unsigned.ipa` (also as
  `dish-ios.ipa`). It does not install as downloaded: it must be
  re-signed with your own certificate and provisioning profile. The
  cosign signature and the SLSA provenance still bind the file to the
  tagged `release.yml` run, so verify them before re-signing. With the
  secrets the signed archive goes to App Store Connect and TestFlight,
  and the GitHub Release carries the supporting files.
- **Vendored-header scanners.** `satellite/lib/` and
  `satellite/vigem/include/` are not understood by ecosystem scanners.
  We feed OSV-Scanner a synthetic `osv-scanner.toml` derived from
  [`lib/VENDORED.md` in TinkerNorth/satellite](https://github.com/TinkerNorth/satellite/blob/main/lib/VENDORED.md), and the
  `vendored-freshness` CI job fails if any `Last-vendored:` date is
  more than 90 days old. This is best-effort, not exhaustive: file an
  advisory if you spot a vendored component that's missing from
  `VENDORED.md`.
- **macOS virtual pads are entitlement-gated.** The macOS satellite
  backend synthesizes virtual DualShock 4 controllers via
  `IOHIDUserDevice`, which requires the
  `com.apple.developer.hid.virtual.device` entitlement. Production
  (signed) builds carry it; CI artifacts and local unentitled builds
  detect the missing entitlement at runtime and fall back to the
  historical inert backend: the protocol stack runs, but every
  controller descriptor applies as `backendUnavailable`. The CI
  artifact name (`satellite-macos-stub-...`) reflects that fallback.
  Don't open a vulnerability report for the absence of virtual-gamepad
  creation in an unentitled build: it's the documented, probe-enforced
  fallback.
