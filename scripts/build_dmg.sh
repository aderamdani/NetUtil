#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0.0")
APP_NAME="NetUtil"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DIST_DIR="$REPO_ROOT/dist"
APP_PATH="$DIST_DIR/${APP_NAME}.app"
BACKGROUND="$REPO_ROOT/scripts/dmg_background.png"

echo "▸ Building ${DMG_NAME}..."

# ── 1. Generate background ────────────────────────────────────────────────────
echo "▸ Generating DMG background..."
swift "$REPO_ROOT/scripts/generate_background.swift" "$BACKGROUND"

# ── 2. Ensure app exists in dist/ ────────────────────────────────────────────
ARCHIVE_PATH="$REPO_ROOT/build/${APP_NAME}.xcarchive"
ARCHIVE_APP="$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "▸ App not found at $APP_PATH — building..."

    xcodebuild \
        -scheme "$APP_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        archive -quiet

    mkdir -p "$DIST_DIR"
    cp -R "$ARCHIVE_APP" "$APP_PATH"
    echo "▸ App copied from archive"
fi

# ── 3. Remove old DMG ─────────────────────────────────────────────────────────
rm -f "$DIST_DIR/${APP_NAME}-"*.dmg

# ── 4. Create DMG ─────────────────────────────────────────────────────────────
echo "▸ Creating DMG..."
create-dmg \
    --volname "NetUtil" \
    --background "$BACKGROUND" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 120 \
    --text-size 13 \
    --icon "${APP_NAME}.app" 165 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 495 190 \
    "$DIST_DIR/$DMG_NAME" \
    "$DIST_DIR/" 2>/dev/null || true

if [ -f "$DIST_DIR/$DMG_NAME" ]; then
    SIZE=$(du -sh "$DIST_DIR/$DMG_NAME" | cut -f1)
    echo "✓ Done: dist/$DMG_NAME ($SIZE)"
else
    echo "✗ DMG creation failed"
    exit 1
fi
