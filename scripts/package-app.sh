#!/bin/zsh
set -euo pipefail

ROOT="/Users/xiayh/Projects/hermes-station-menubar"
BUILD_DIR="$ROOT/.build/debug"
APP_DIR="$ROOT/dist/HermesStation.app"
ZIP_PATH="$ROOT/dist/HermesStation-latest.zip"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
VERSION="0.1.0"
BUILD_NUMBER="$(date '+%Y%m%d%H%M%S')"
BUILD_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

cd "$ROOT"
swift build

rm -rf "$APP_DIR"
rm -f "$ZIP_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/HermesStation" "$MACOS_DIR/HermesStation"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>HermesStation</string>
  <key>CFBundleIdentifier</key>
  <string>com.xiayh.HermesStation</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>HermesStation</string>
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

codesign --force --deep --sign - "$APP_DIR" >/dev/null
(
  cd "$ROOT/dist"
  /usr/bin/zip -qry -X "$ZIP_PATH" "HermesStation.app"
)

echo "App bundle created at: $APP_DIR"
echo "Zip archive created at: $ZIP_PATH"
