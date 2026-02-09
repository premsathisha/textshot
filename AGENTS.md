# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## High-level Architecture

This project is a native Swift menu bar macOS utility for fast region OCR. There is no Electron runtime.

- `native/settings-app`: Main Swift app runtime (status item, hotkey, capture flow, OCR, settings, permissions, toast)
- `scripts`: Build/test/release helpers
- `build`: Release configuration files (export options, entitlements)
- `assets`: App icon and tray assets

## Common Commands

- `npm run build`: Build universal native binary and app bundle (`bin/Text Shot.app`)
- `npm start`: Launch the native app bundle
- `npm test`: Native unit tests (`swift test`)
- `npm run typecheck`: Compile-check native Swift package
- `npm run clean`: Remove generated files (`bin`, `dist`, `dist-native`, `release`, Swift caches)

## Release Requirements (Mandatory Every Edit Cycle)

- Keep semantic version in `package.json` aligned with native release policy.
- Build native app bundle:
  - `npm run build`
- Build DMG and copy artifacts to `release/`:
  - `npm run release:native:minor`
- Ensure `release/` contains only the latest DMG and matching `.sha256`.
- `dist-native/` is transient/internal and must not be used as a distribution location.

## Version Policy

- Native cutover release: `1.0.0`
- Every new DMG must bump the version.
- Version progression is patchless and follows:
  - `1.0.0` -> `1.1.0` -> ... -> `1.9.0` -> `2.0.0` -> ...
- Keep only the latest DMG and checksum in `release/`; delete older release artifacts.
