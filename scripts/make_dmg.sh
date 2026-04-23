#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Build a distribution-style DMG:
#   - staged folder with the .app + an Applications symlink (drag-to-install)
#   - Finder view with fixed window size and icon positions
#   - custom volume icon sourced from the app icon (optional)
#
# Usage: make_dmg.sh <app_path> <output_dmg> [<volume_name>] [<volume_icon_png>]
set -euo pipefail

APP_PATH=${1:?"app path required"}
OUTPUT_DMG=${2:?"output dmg path required"}
VOLUME_NAME=${3:-OpenVibbleDesktop}
VOLUME_ICON_PNG=${4:-}

if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app not found at $APP_PATH" >&2
    exit 1
fi

APP_BASENAME=$(basename "$APP_PATH")
WORK=$(mktemp -d -t ov-dmg)
trap 'rm -rf "$WORK"; hdiutil detach "/Volumes/$VOLUME_NAME" -quiet 2>/dev/null || true' EXIT

STAGE="$WORK/stage"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Optional volume icon: convert a square PNG to .icns in place.
if [[ -n "$VOLUME_ICON_PNG" && -f "$VOLUME_ICON_PNG" ]]; then
    ICONSET="$WORK/VolumeIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$VOLUME_ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        dbl=$((size * 2))
        sips -z $dbl $dbl "$VOLUME_ICON_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$STAGE/.VolumeIcon.icns"
fi

RW_DMG="$WORK/rw.dmg"
hdiutil create \
    -srcfolder "$STAGE" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDRW \
    -size 64m \
    "$RW_DMG" >/dev/null

MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" >/dev/null
sleep 2

if [[ -f "$STAGE/.VolumeIcon.icns" ]]; then
    # Already copied in via srcfolder; mark the volume root to use it.
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

osascript <<OSA
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {280, 180, 900, 560}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set label position of viewOptions to bottom
        set position of item "$APP_BASENAME" of container window to {160, 180}
        set position of item "Applications" of container window to {460, 180}
        update without registering applications
        delay 1
        close
    end tell
end tell
OSA

sync
hdiutil detach "$MOUNT_DIR" -quiet

rm -f "$OUTPUT_DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG" >/dev/null

echo "DMG built: $OUTPUT_DMG"
