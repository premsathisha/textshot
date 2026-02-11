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
