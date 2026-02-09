#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GENERATED_PATHS=(
  ".DS_Store"
  ".clang-module-cache"
  ".swiftpm-module-cache"
  "native/settings-app/.build"
  "dist"
  "dist-native"
  "release"
  "bin"
)

for path in "${GENERATED_PATHS[@]}"; do
  rm -rf -- "$path"
done

if [[ "${REMOVE_NODE_MODULES:-0}" == "1" ]]; then
  rm -rf -- "node_modules"
fi

find . -maxdepth 1 -type d -name '(A Document Being Saved By swift-*' -exec rm -rf -- {} +

echo "Removed generated artifacts and caches."
