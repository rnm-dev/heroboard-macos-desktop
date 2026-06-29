---
name: release
description: Release a new version of the Heroboard macOS app — tag the version, build Release, Developer-ID sign + notarize, zip, and publish a GitHub Release (zip asset) on rnm-dev/heroboard-macos-desktop. The shipped app auto-updates users from these releases. Use when shipping a new macOS app version.
---

# Release the Heroboard macOS app

Distribution is a **`.zip` on GitHub Releases** of **`rnm-dev/heroboard-macos-desktop`**. The shipped
app auto-updates from there via `AppUpdater` (`Heroboard/AppDelegate.swift`), and the README's
"latest release" link points there. Run from the repo root.

## Prerequisites
- `brew install xcodegen`; `SV_DEVELOPMENT_TEAM` env var (Apple Team ID).
- **Developer ID Application** cert + a notarytool profile (`xcrun notarytool store-credentials …`) —
  needed because users download from the web, so the app must pass Gatekeeper.
- `gh` authed with push access to `rnm-dev/heroboard-macos-desktop`.
- ⚠️ The repo must be **public** for users to download release assets (it's currently PRIVATE — make
  it public like the plugin repo).

## 1 — Tag the version
The build stamps `CFBundleShortVersionString` (+ heartbeat `v`) from the latest git tag.
```bash
git tag v1.2.3 && git push origin v1.2.3
```

## 2 — Build + sign + notarize → zip
```bash
make build                                              # xcodegen + xcodebuild Release
APP=build/Build/Products/Release/Heroboard.app
codesign --force --options runtime --timestamp --deep \
  --sign "Developer ID Application: <Name> (<TEAMID>)" "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" macos-heroboard.zip   # AppUpdater expects this zip shape
xcrun notarytool submit macos-heroboard.zip --keychain-profile <profile> --wait
xcrun stapler staple "$APP" && ditto -c -k --sequesterRsrc --keepParent "$APP" macos-heroboard.zip  # staple + re-zip
```
(`make all` does the build + zip without signing/notarize — use the explicit steps above for a real release.)

## 3 — Publish the GitHub Release
```bash
gh release create v1.2.3 macos-heroboard.zip \
  --repo rnm-dev/heroboard-macos-desktop --title v1.2.3 --notes "…"
```
`AppUpdater` picks the newest semver tag and offers users the update; the README's
`…/releases/latest` link resolves to it.

## Verify
- `gh release view v1.2.3 --repo rnm-dev/heroboard-macos-desktop` lists the `macos-heroboard.zip` asset.
- Unzip on another Mac → `Heroboard.app` opens with no Gatekeeper "damaged" warning (= notarized + stapled).
- A user on the previous version gets the update prompt.

> A self-hosted DMG variant (`bin/release-prod.sh` → `heroboard.app/downloads`) exists from an earlier
> direction, but the chosen path is this GitHub-zip flow. Ignore the DMG script unless self-hosting returns.
