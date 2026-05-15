#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Autopilot for Codex"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
DMG_PATH="${1:-$ROOT_DIR/dist/$APP_NAME $VERSION.dmg}"

if [[ ! -f "$DMG_PATH" ]]; then
    echo "DMG not found: $DMG_PATH" >&2
    echo "Run ./scripts/package-dmg.sh first." >&2
    exit 1
fi

submit_args=("$DMG_PATH" --wait)

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    submit_args+=(--keychain-profile "$NOTARYTOOL_PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    submit_args+=(
        --apple-id "$APPLE_ID"
        --team-id "$APPLE_TEAM_ID"
        --password "$APPLE_APP_SPECIFIC_PASSWORD"
    )
elif [[ -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER:-}" && -n "${APPLE_API_KEY:-}" ]]; then
    submit_args+=(
        --key "$APPLE_API_KEY"
        --key-id "$APPLE_API_KEY_ID"
        --issuer "$APPLE_API_ISSUER"
    )
else
    cat >&2 <<'EOF'
Missing notarization credentials.

Use one of:
  NOTARYTOOL_PROFILE=<stored-profile>
  APPLE_ID + APPLE_TEAM_ID + APPLE_APP_SPECIFIC_PASSWORD
  APPLE_API_KEY + APPLE_API_KEY_ID + APPLE_API_ISSUER

To create a stored profile:
  xcrun notarytool store-credentials autopilot-codex \
    --apple-id "you@example.com" \
    --team-id "TEAMID" \
    --password "app-specific-password"
EOF
    exit 2
fi

xcrun notarytool submit "${submit_args[@]}"
xcrun stapler staple "$DMG_PATH"
spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"

echo "$DMG_PATH"
