# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## High-level Architecture

This project is a native menu bar macOS utility for fast region OCR. It is now a Swift application (no Electron runtime).

- `native/settings-app`: Main Swift app runtime (status item, hotkey, capture flow, OCR, settings, permissions, toast)
- `scripts`: Build/release helpers for universal binaries and DMG generation
- `build`: Release configuration files (including native export options)

## Common Commands

- `npm run build`: Build universal native binary and app bundle (`bin/Text Shot.app`)
- `npm start`: Launch the native app bundle
- `npm test`: Native compile-check smoke test
- `npm run typecheck`: Compile-check native Swift package
- `npm run clean`: Remove generated files (`bin`, `dist`, `dist-native`, `release`, Swift caches)

## Release Requirements (Mandatory Every Edit Cycle)

- Keep semantic version in `package.json` aligned with native release policy.
- Build native app bundle:
  - `npm run build`
- Build DMG and copy artifacts to `release/`:
  - `npm run release:native:minor`

## Version Policy

- Native cutover release: `1.0.0`
- Future updates: bump minor only (`1.1.0`, `1.2.0`, ...)
- No patch versions unless explicitly requested
