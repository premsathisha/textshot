#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_DIR="$ROOT_DIR/native/settings-app"
# Use /tmp for SwiftPM scratch builds to avoid occasional sqlite build.db I/O errors under Documents/iCloud.
ARM_BUILD="/tmp/text-shot-settings-build-arm64"
X64_BUILD="/tmp/text-shot-settings-build-x86_64"
OUT_DIR="$ROOT_DIR/bin"
APP_DIR="$OUT_DIR/Text Shot.app"
MODULE_CACHE_DIR="$ROOT_DIR/.swiftpm-module-cache"
CLANG_CACHE_DIR="$ROOT_DIR/.clang-module-cache"
APP_VERSION="$(awk -F'\"' '/\"version\"/ {print $4; exit}' "$ROOT_DIR/package.json")"
BUILD_NUMBER="$(date +%Y%m%d%H%M)"

fail() {
  echo "build-settings-app: $*" >&2
  exit 1
}

mkdir -p "$OUT_DIR"
mkdir -p "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"

export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

swift build --package-path "$SETTINGS_DIR" -c release --arch arm64 --scratch-path "$ARM_BUILD"
swift build --package-path "$SETTINGS_DIR" -c release --arch x86_64 --scratch-path "$X64_BUILD"

rm -rf -- "$APP_DIR"

lipo -create \
  "$ARM_BUILD/release/text-shot" \
  "$X64_BUILD/release/text-shot" \
  -output "$OUT_DIR/text-shot"

chmod +x "$OUT_DIR/text-shot"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp -f "$OUT_DIR/text-shot" "$APP_DIR/Contents/MacOS/Text Shot"
chmod +x "$APP_DIR/Contents/MacOS/Text Shot"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Text Shot</string>
  <key>CFBundleIdentifier</key>
  <string>com.textshot.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Text Shot</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -n "${APPLE_DEVELOPER_ID_APP:-}" ]]; then
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$APPLE_DEVELOPER_ID_APP" \
    --identifier "com.textshot.app" \
    "$APP_DIR"
else
  codesign \
    --force \
    --deep \
    --sign - \
    --identifier "com.textshot.app" \
    "$APP_DIR"
fi

codesign --verify --deep --strict "$APP_DIR"

echo "Built universal native app binary at $OUT_DIR/text-shot"
echo "Built app bundle at $APP_DIR"
