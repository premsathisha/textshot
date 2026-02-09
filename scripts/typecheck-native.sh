#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/native/settings-app"
MODULE_CACHE_DIR="$ROOT_DIR/.swiftpm-module-cache"
CLANG_CACHE_DIR="$ROOT_DIR/.clang-module-cache"
SCRATCH_PATH="/tmp/text-shot-settings-build-check"

mkdir -p "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"

export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR"

swift build --package-path "$PACKAGE_DIR" --scratch-path "$SCRATCH_PATH"
