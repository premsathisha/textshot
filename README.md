# Text Shot

Menu bar macOS utility for fast region OCR: hotkey -> drag capture -> local Vision OCR -> clipboard copy.

## Highlights

- Menu bar only (`LSUIElement`), no Dock UI in packaged builds.
- Native capture using `/usr/sbin/screencapture -i -x`.
- Local OCR only via Apple Vision (Swift helper).
- Retry chain in Electron:
  1. Accurate + language correction ON
  2. Accurate + language correction OFF
  3. Fast
- Optional auto-paste (OFF by default), guarded by Accessibility permission.
- No analytics SDK, no cloud APIs, no text/image payload logging.

## Project Layout

- `src/main`: Electron main process (tray, hotkey, capture flow, OCR orchestration, permissions, settings)
- `src/preload`: Preload bridge for settings window
- `src/renderer`: Minimal settings UI
- `native/ocr-helper`: Swift CLI (Vision OCR)
- `scripts`: Helper build/copy and notarization hook
- `build`: Entitlements templates
- `tests`: Unit and e2e scaffolding

## Local Build

Prerequisites:

- macOS 13+
- Xcode Command Line Tools
- Swift 5.9+
- Node.js 20+

Install dependencies:

```bash
npm install
```

Build TypeScript + helper:

```bash
npm run build
```

Run app:

```bash
npm start
```

## Development Notes

- Default hotkey: `CommandOrControl+Shift+2`
- Helper binary expected at `bin/ocr-helper` for local runs.
- In debug mode, capture temp image is retained; otherwise deleted immediately.

## Helper Build Details

Build universal helper manually:

```bash
bash scripts/build-helper.sh
```

This creates:

- `bin/ocr-helper` (arm64 + x86_64 universal)

## Permissions and Troubleshooting

Screen Recording denial behavior:

- Prompt appears only after user-triggered hotkey capture fails.
- Modal includes:
  - Deep link attempt to Screen Recording settings
  - Manual path: `System Settings -> Privacy & Security -> Screen Recording`

Auto-paste Accessibility behavior:

- Only applies when `Auto-paste` is enabled.
- On failure, app keeps clipboard copy successful and shows guidance:
  - `System Settings -> Privacy & Security -> Accessibility`

## Packaging

Create distributables:

```bash
npm run dist
```

Configured outputs:

- `dmg`
- `zip`

Key packaging settings:

- Hardened runtime enabled
- Entitlements templates:
  - `build/entitlements.mac.plist`
  - `build/entitlements.mac.inherit.plist`
- Helper bundled as extra resource: `Resources/bin/ocr-helper`

## Notarization-Ready Setup

`electron-builder` calls `scripts/notarize.js` after signing stage.

The hook checks for:

- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

If missing, notarization is skipped intentionally.

Typical release flow:

1. Sign app in release pipeline with Developer ID.
2. Export Apple credentials via environment variables.
3. Run `npm run dist` in CI with signing enabled.
4. Submit notarization and staple as part of release pipeline.

## Distribution Checklist

- Verify tray app launches as menu bar utility.
- Verify global hotkey capture and OCR flow.
- Verify temp cleanup when debug mode is off.
- Verify permission modals and manual guidance text.
- Verify auto-paste fallback (copy still works if Accessibility denied).
- Verify helper exists inside packaged app resources.
- Verify no analytics/network dependencies are introduced.
