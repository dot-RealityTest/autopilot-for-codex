#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Autopilot for Codex"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
DMG_PATH="$DIST_DIR/$APP_NAME $VERSION.dmg"

find_developer_id() {
    security find-identity -v -p codesigning 2>/dev/null \
        | awk -F\" '/Developer ID Application/ {print $2; exit}'
}

SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:-$(find_developer_id)}"
DMG_SIGN_IDENTITY="${MACOS_DMG_SIGN_IDENTITY:-$SIGN_IDENTITY}"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-}"
LEGACY_DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
UNVERSIONED_DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/build-app.sh" >/dev/null

if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Signing app with: $SIGN_IDENTITY"
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
    codesign --verify --deep --strict --verbose=2 "$APP_DIR"
else
    echo "Warning: no Developer ID Application identity found. DMG will be local-use only." >&2
fi

rm -f "$DMG_PATH" "$LEGACY_DMG_PATH" "$UNVERSIONED_DMG_PATH"

CREATE_DMG_ARGS=(
    npx --yes create-dmg@latest
    "$APP_DIR"
    "$DIST_DIR"
    --overwrite
    --dmg-title "$APP_NAME"
)

if [[ -n "$DMG_SIGN_IDENTITY" ]]; then
    CREATE_DMG_ARGS+=(--identity="$DMG_SIGN_IDENTITY")
else
    CREATE_DMG_ARGS+=(--no-code-sign)
fi

"${CREATE_DMG_ARGS[@]}"

if [[ ! -f "$DMG_PATH" ]]; then
    CREATED_DMG="$(find "$DIST_DIR" -maxdepth 1 -type f -name "$APP_NAME*.dmg" -print -quit)"
    if [[ -n "${CREATED_DMG:-}" && -f "$CREATED_DMG" ]]; then
        mv "$CREATED_DMG" "$DMG_PATH"
    fi
fi

if [[ ! -f "$DMG_PATH" ]]; then
    echo "DMG was not created: $DMG_PATH" >&2
    exit 1
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARYTOOL_PROFILE="$NOTARY_PROFILE" "$ROOT_DIR/scripts/notarize-dmg.sh" "$DMG_PATH"
fi

echo "$DMG_PATH"
if [[ -n "$SIGN_IDENTITY" ]]; then
    spctl -a -vv --type execute "$APP_DIR" || true
fi
