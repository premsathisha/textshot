#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT_DIR/bin/ocr-helper"

if [[ ! -x "$SRC" ]]; then
  echo "Missing helper at $SRC. Run npm run build:helper first."
  exit 1
fi

echo "Helper ready at $SRC"
