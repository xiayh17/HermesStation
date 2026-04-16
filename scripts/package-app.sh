#!/bin/zsh
set -euo pipefail

ROOT="/Users/xiayh/Projects/hermes-station-menubar"
BUILD_DIR="$ROOT/.build/debug"
APP_DIR="$ROOT/dist/HermesStationMenuBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
VERSION="0.1.0"
BUILD_NUMBER="$(date '+%Y%m%d%H%M%S')"
BUILD_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

cd "$ROOT"
swift build

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$BUILD_DIR/HermesStationMenuBar" "$MACOS_DIR/HermesStationMenuBar"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>HermesStationMenuBar</string>
  <key>CFBundleIdentifier</key>
  <string>com.xiayh.HermesStationMenuBar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>HermesStationMenuBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>HermesBuildTimestamp</key>
  <string>${BUILD_TIMESTAMP}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "App bundle created at: $APP_DIR"
