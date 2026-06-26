---
name: release
description: Release a new version of the Heroboard macOS app — pick/tag the version, build Release, Developer ID sign + notarize, build the DMG, upload to prod, and update the updater metadata. Use when shipping a new macOS app version. Wraps bin/release-prod.sh.
---

# Release the Heroboard macOS app

Builds a **signed + notarized DMG** and publishes it. The whole pipeline is `bin/release-prod.sh`;
this skill is the runbook around it. Run everything from the repo root.

## Prerequisites (one-time)
- `brew install xcodegen`
- `SV_DEVELOPMENT_TEAM` env var — your Apple Team ID (consumed by `project.yml` signing).
- **Developer ID Application** cert in the login keychain — required for distribution outside the
  App Store. List with `security find-identity -v -p codesigning`.
- A notarytool credential profile:
  `xcrun notarytool store-credentials heroboard --apple-id <id> --team-id <TEAMID> --password <app-specific-pwd>`
  (any name; the script uses `NOTARY_PROFILE`).
- SSH access to the prod box (`root@94.247.128.103`).

## 1 — Pick and tag the version
The build stamps `CFBundleShortVersionString` (and the heartbeat `v`) from the **latest git tag**
(`Makefile` / `release-prod.sh` derive it via `git describe --tags`). Bump = a new tag:
```bash
git tag v1.2.3 && git push origin v1.2.3        # or skip and pass VERSION=1.2.3 below
```
Branch-prefix → bump rules live in `CONTRIBUTING.md` / `bin/semver.sh` (helper, not auto-wired).

## 2 — Build + sign + notarize + DMG + upload + appcast (one command)
```bash
DEVELOPER_ID_APP="Developer ID Application: <Name> (<TEAMID>)" \
NOTARY_PROFILE=heroboard \
bin/release-prod.sh                              # VERSION from the tag, or VERSION=1.2.3 bin/release-prod.sh
```
Produces `Heroboard-<ver>.dmg` + `latest.json` + `appcast.xml` and uploads them to
`root@94.247.128.103:/srv/heroboard-downloads/macos/` → `https://heroboard.app/downloads/macos/`.

⚠️ Without `DEVELOPER_ID_APP` / `NOTARY_PROFILE` it still builds + uploads, but the DMG won't pass
Gatekeeper on other Macs (the script warns). Don't ship an unsigned/un-notarized build.

## 3 — Make the *running* app's updater find it
The shipped app updates via **AppUpdater → GitHub Releases** (`Heroboard/AppDelegate.swift`), **not**
the server appcast yet. So until HB-399 switches the updater, also cut a GitHub release so existing
users get the update:
```bash
make all                                         # builds Release + macos-heroboard.zip
gh release create v1.2.3 macos-heroboard.zip --repo heroboard/macos-heroboard --title v1.2.3 --notes "…"
```
The self-hosted `appcast.xml` becomes the real update feed once **HB-399** points the updater at it
and **HB-398** serves `/downloads/` over HTTPS (`:443` block). Until then `release-prod.sh`'s upload
lands on the server but isn't the live update source.

## Verify
- DMG opens on a *different* Mac with no Gatekeeper "damaged / can't be opened" warning (= notarized + stapled).
- `shasum -a 256 Heroboard-<ver>.dmg` matches `latest.json`.
- A user on the previous version gets the update prompt (GitHub path).

## Quick local build (no release)
`make all` → Release build + `macos-heroboard.zip` only (no signing / notarize / upload).
