# Text Shot

Native macOS menu bar OCR utility in Swift.

Flow: global hotkey -> region capture -> Vision OCR (local) -> clipboard -> optional auto-paste.

## Architecture

- `native/settings-app`: Primary native Swift app (menu bar runtime + settings UI)
  - `AppController`: orchestration for capture/OCR/clipboard/permissions
  - `HotkeyManager`: global hotkey registration via Carbon
  - `SettingsStoreV2` + `SettingsMigrator`: `settings-v2.json` migration/persistence
  - `ToastPresenter`: native HUD-style confirmation panel
- `scripts/build-settings-app.sh`: builds universal binary + app bundle (`bin/Text Shot.app`)
- `scripts/release-native.sh`: version bump + DMG generation + optional notarization

## Settings Schema (v2)

Stored at:

- `~/Library/Application Support/Text Shot/settings-v2.json`

Schema:

```json
{
  "schemaVersion": 2,
  "hotkey": "CommandOrControl+Shift+2",
  "showConfirmation": true,
  "launchAtLogin": false,
  "autoPaste": false,
  "lastPermissionPromptAt": 0,
  "lastAccessibilityPromptAt": 0
}
```

Notes:

- `debugMode` was removed.
- Updater-related settings were removed.
- One-time migration reads legacy `settings.json` from old Electron locations.

## Hotkey Rules

Allowed:

- Any shortcut with one or more modifiers (`Command`, `Control`, `Option`, `Shift`)
- Modifier-free function keys (`F1` ... `F24`)

Blocked:

- Printable keys without modifiers (`K`, `3`, `Space`, etc.)

On hotkey registration failure, the previous active shortcut remains active.

## Build

```bash
npm run build
```

Output:

- `bin/text-shot` (universal binary)
- `bin/Text Shot.app`

## Run

```bash
npm start
```

## Test

```bash
npm test
```

## Release / DMG

Cutover release (`1.0.0`):

```bash
npm run release:native:cutover
```

Future releases (minor only):

```bash
npm run release:native:minor
```

Rules:

- First native release is `1.0.0`
- Future releases bump minor only (`1.1.0`, `1.2.0`, ...)
- DMG output name: `Text Shot-<version>.dmg`
- Copied to `release/` with SHA-256 checksum

Notarization env vars (optional but recommended):

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
