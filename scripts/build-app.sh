#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
APP_DIR="$ROOT_DIR/.build/Cockpit.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ASSETS_DIR="$ROOT_DIR/Assets"
BINARY_PATH="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIGURATION/Cockpit"

cd "$ROOT_DIR"

if [[ "$CONFIGURATION" == "release" ]]; then
  swift build -c release
else
  swift build
fi

if [[ ! -f "$ASSETS_DIR/NEOIcon.icns" ]]; then
  echo "Missing NEO app icon: $ASSETS_DIR/NEOIcon.icns" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY_PATH" "$MACOS_DIR/Cockpit"
cp "$ASSETS_DIR/NEOIcon.icns" "$RESOURCES_DIR/NEOIcon.icns"
chmod +x "$MACOS_DIR/Cockpit"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Cockpit</string>
  <key>CFBundleIconFile</key>
  <string>NEOIcon</string>
  <key>CFBundleIdentifier</key>
  <string>ai.speer.cockpit</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Cockpit</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

printf '%s\n' "$APP_DIR"
