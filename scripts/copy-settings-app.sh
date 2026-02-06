#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT_DIR/bin/text-shot-settings"

if [[ ! -x "$SRC" ]]; then
  echo "Missing settings app binary at $SRC. Run npm run build:settings-app first."
  exit 1
fi

echo "Settings app ready at $SRC"
