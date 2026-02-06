#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

log_step() {
  printf '\n[%s] %s\n' "dev" "$1"
}

fail() {
  printf '[dev] ERROR: %s\n' "$1" >&2
  exit 1
}

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    fail "Missing required tool: $tool"
  fi
}

needs_npm_install() {
  [[ ! -d node_modules ]] && return 0
  [[ package.json -nt node_modules ]] && return 0
  if [[ -f package-lock.json && package-lock.json -nt node_modules ]]; then
    return 0
  fi
  return 1
}

needs_helper_build() {
  local helper_bin="bin/ocr-helper"
  [[ ! -x "$helper_bin" ]] && return 0

  local helper_src_dir="native/ocr-helper"
  if find "$helper_src_dir" -type f \( -name '*.swift' -o -name 'Package.swift' \) -newer "$helper_bin" | grep -q .; then
    return 0
  fi

  return 1
}

needs_helper_copy() {
  local src="bin/ocr-helper"
  local dst="resources/bin/ocr-helper"

  [[ ! -f "$dst" ]] && return 0
  [[ "$src" -nt "$dst" ]] && return 0

  return 1
}

log_step "Verifying required tools"
require_tool node
require_tool npm
require_tool swift

if needs_npm_install; then
  log_step "Installing Node dependencies"
  npm install
else
  log_step "Node dependencies already installed (skipping)"
fi

if needs_helper_build; then
  log_step "Building Swift OCR helper (release, universal)"
  bash scripts/build-helper.sh
else
  log_step "Swift OCR helper is up to date (skipping build)"
fi

if [[ ! -x bin/ocr-helper ]]; then
  fail "Expected helper binary at bin/ocr-helper after build"
fi

if needs_helper_copy; then
  log_step "Copying OCR helper into Electron resources folder"
  mkdir -p resources/bin
  cp bin/ocr-helper resources/bin/ocr-helper
  chmod +x resources/bin/ocr-helper
else
  log_step "Electron resources helper already up to date (skipping copy)"
fi

log_step "Compiling Electron TypeScript"
npm run build:ts

log_step "Syncing renderer static files"
npm run copy:renderer

log_step "Starting Electron app in development mode"
npm start
