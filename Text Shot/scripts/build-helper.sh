#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER_DIR="$ROOT_DIR/native/ocr-helper"
ARM_BUILD="$HELPER_DIR/.build/arm64"
X64_BUILD="$HELPER_DIR/.build/x86_64"
OUT_DIR="$ROOT_DIR/bin"

mkdir -p "$OUT_DIR"

swift build --package-path "$HELPER_DIR" -c release --arch arm64 --scratch-path "$ARM_BUILD"
swift build --package-path "$HELPER_DIR" -c release --arch x86_64 --scratch-path "$X64_BUILD"

lipo -create \
  "$ARM_BUILD/release/ocr-helper" \
  "$X64_BUILD/release/ocr-helper" \
  -output "$OUT_DIR/ocr-helper"

chmod +x "$OUT_DIR/ocr-helper"
echo "Built universal helper at $OUT_DIR/ocr-helper"
