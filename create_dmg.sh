#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DailyTodo"
APP_BUNDLE="$APP_NAME.app"
VOLUME_NAME="Daily Todo"
DMG_NAME="$APP_NAME.dmg"
STAGING_DIR=".dmg-staging"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "$APP_BUNDLE not found, building it first..."
    ./build.sh
fi

echo "Staging DMG contents..."
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating $DMG_NAME..."
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

rm -rf "$STAGING_DIR"

echo "Done: $DMG_NAME"
echo "Share this file — recipients open it, then drag Daily Todo.app into Applications."
