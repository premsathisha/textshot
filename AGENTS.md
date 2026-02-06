# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## High-level Architecture

This project is a menu bar macOS utility for fast region OCR. It is an Electron application with a native Swift helper for OCR.

- `src/main`: Electron main process (tray, hotkey, capture flow, OCR orchestration, permissions, settings)
- `src/preload`: Preload bridge for settings window
- `src/renderer`: Minimal settings UI
- `native/ocr-helper`: Swift CLI for local OCR using Apple Vision.
- `scripts`: Helper scripts for building, copying, and notarization.
- `build`: Entitlements templates for macOS.
- `tests`: Unit and e2e tests.

## Common Commands

- `npm install`: Install dependencies.
- `npm run dev`: Run the app in development mode.
- `npm run build`: Build TypeScript and the Swift helper.
- `npm start`: Run the built app.
- `npm test`: Run tests with vitest.
- `npm run dist`: Package the application for distribution.
- `npm run clean`: Remove generated files (`dist`, `bin`, `release`).
- `bash scripts/build-helper.sh`: Manually build the universal Swift OCR helper.
- `npm run typecheck`: Typecheck the project.
