# Autopilot for Codex Distribution

This project ships as a signed macOS `.app` inside a drag-to-Applications DMG.

The packaging script uses [`create-dmg`](https://github.com/sindresorhus/create-dmg) to build the installer image.

## Build the App

```sh
./scripts/build-app.sh
```

Output:

```text
dist/Autopilot for Codex.app
```

## Create a Signed DMG

```sh
./scripts/package-dmg.sh
```

Output:

```text
dist/Autopilot for Codex 0.1.0.dmg
```

The script will automatically use the first available `Developer ID Application` certificate.

To choose a specific signing identity:

```sh
MACOS_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/package-dmg.sh
```

## Notarize

Preferred setup:

```sh
xcrun notarytool store-credentials autopilot-codex \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

Then package and notarize:

```sh
NOTARYTOOL_PROFILE=autopilot-codex ./scripts/package-dmg.sh
```

Or notarize an existing DMG:

```sh
NOTARYTOOL_PROFILE=autopilot-codex ./scripts/notarize-dmg.sh
```

The notarization script submits the DMG, waits for Apple, staples the result, and verifies Gatekeeper.

## Credential Alternatives

Apple ID credentials:

```sh
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./scripts/notarize-dmg.sh
```

App Store Connect API key:

```sh
APPLE_API_KEY="/path/to/AuthKey_ABC123.p8" \
APPLE_API_KEY_ID="ABC123" \
APPLE_API_ISSUER="issuer-uuid" \
./scripts/notarize-dmg.sh
```

## Validate

```sh
codesign --verify --deep --strict --verbose=2 "dist/Autopilot for Codex.app"
spctl -a -vv --type execute "dist/Autopilot for Codex.app"
spctl -a -vv -t open --context context:primary-signature "dist/Autopilot for Codex 0.1.0.dmg"
```
