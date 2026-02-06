#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_DIR="$ROOT_DIR/native/settings-app"
ARM_BUILD="$SETTINGS_DIR/.build/arm64"
X64_BUILD="$SETTINGS_DIR/.build/x86_64"
OUT_DIR="$ROOT_DIR/bin"
MODULE_CACHE_DIR="$ROOT_DIR/.swiftpm-module-cache"
CLANG_CACHE_DIR="$ROOT_DIR/.clang-module-cache"

mkdir -p "$OUT_DIR"
mkdir -p "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"

export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

swift build --package-path "$SETTINGS_DIR" -c release --arch arm64 --scratch-path "$ARM_BUILD"
swift build --package-path "$SETTINGS_DIR" -c release --arch x86_64 --scratch-path "$X64_BUILD"

lipo -create \
  "$ARM_BUILD/release/text-shot-settings" \
  "$X64_BUILD/release/text-shot-settings" \
  -output "$OUT_DIR/text-shot-settings"

chmod +x "$OUT_DIR/text-shot-settings"
echo "Built universal settings app at $OUT_DIR/text-shot-settings"
