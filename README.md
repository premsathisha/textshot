# Text Shot

Text Shot is a native macOS menu bar OCR utility written in Swift.

Flow: global hotkey -> region capture -> Vision OCR (local) -> clipboard.

## Architecture

- `native/settings-app`: Native runtime and settings UI
  - `AppController`: capture/OCR/clipboard/permissions orchestration
  - `HotkeyManager` + `HotkeyBindingController`: global hotkey rules and registration
  - `SettingsStoreV2` + `SettingsMigrator`: migration and persistence for `settings-v3.json`
  - `ToastPresenter`: native confirmation HUD
- `scripts/build-settings-app.sh`: builds universal binary and app bundle in `bin/`
- `scripts/release-native.sh`: bumps version and creates release DMG artifacts
- `build/`: export options and entitlements for release tooling

## Requirements

- macOS 13+
- Xcode command-line tools (`swift`, `xcodebuild`, `codesign`, `hdiutil`)
- Node.js + npm

## Commands

- `npm run build`: Build universal binary and app bundle (`bin/text-shot`, `bin/Text Shot.app`)
- `npm start`: Launch the built native app bundle
- `npm run typecheck`: Swift compile-check (`swift build`)
- `npm test`: Native unit tests (`swift test`)
- `npm run clean`: Remove generated artifacts and caches (`bin`, `dist`, `dist-native`, `release`, Swift caches)
- `npm run release:native:minor`: Bump minor version and produce release DMG + checksum
- `npm run release:native:cutover`: Force version to `1.0.0` and produce release DMG + checksum

## Settings Schema (v3)

Stored at:

- `~/Library/Application Support/Text Shot/settings-v3.json`

Schema:

```json
{
  "schemaVersion": 3,
  "hotkey": "Shift+Command+2",
  "showConfirmation": true,
  "launchAtLogin": false,
  "lastPermissionPromptAt": 0
}
```

Migration notes:

- Existing `settings-v3.json` / `settings-v2.json` is reused when present.
- A legacy `settings.json` from older builds is imported once when found.

## Hotkey Rules

- Allowed:
  - Any shortcut with one or more modifiers (`Command`, `Control`, `Option`, `Shift`)
  - Modifier-free function keys (`F1` ... `F20`)
- Blocked:
  - Printable keys without modifiers (`A`, `3`, `Space`, etc.)

## Release Artifacts

- `release/` contains distributable artifacts only:
  - `Text Shot-<version>.dmg`
  - `Text Shot-<version>.dmg.sha256`
- `release/` keeps only the latest DMG + checksum.
- `dist-native/` is internal/transient release workspace and is not a distribution location.
- `bin/` is local build output for running and packaging the app.

## Version Policy

- Native cutover release: `1.0.0`
- Every new DMG bumps the version.
- Progression is patchless:
  - `1.0.0` -> `1.1.0` -> ... -> `1.9.0` -> `2.0.0` -> ...

## Optional Notarization Environment Variables

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
