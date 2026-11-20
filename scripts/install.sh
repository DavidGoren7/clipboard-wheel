#!/bin/bash
# Builds a Release copy of Clipboard Wheel, installs it to /Applications (or
# ~/Applications if /Applications isn't writable), and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build
echo "Building…"
if ! xcodebuild -project ClipboardWheel.xcodeproj -scheme ClipboardWheel -configuration Release \
    -derivedDataPath build/DerivedData -allowProvisioningUpdates build > build/install.log 2>&1; then
    grep -E "error:" build/install.log || true
    echo "Build failed. Full log: build/install.log"
    exit 1
fi

APP="build/DerivedData/Build/Products/Release/Clipboard Wheel.app"
DEST="/Applications"
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

pkill -x "Clipboard Wheel" 2>/dev/null && sleep 0.5 || true
rm -rf "$DEST/Clipboard Wheel.app"
cp -R "$APP" "$DEST/"
echo "Installed to $DEST/Clipboard Wheel.app"
open "$DEST/Clipboard Wheel.app" --args "$@"
