#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT_DIR/bin/text-shot"
APP_SRC="$ROOT_DIR/bin/Text Shot.app"

if [[ ! -x "$SRC" ]]; then
  echo "Missing native app binary at $SRC. Run npm run build:settings-app first."
  exit 1
fi

if [[ ! -d "$APP_SRC" ]]; then
  echo "Missing native app bundle at $APP_SRC. Run npm run build:settings-app first."
  exit 1
fi

echo "Native app binary ready at $SRC"
echo "Native app bundle ready at $APP_SRC"
