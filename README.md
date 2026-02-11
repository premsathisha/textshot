# Text Shot

Text Shot is a lightweight macOS OCR utility for fast text extraction directly from your screen. It runs entirely on-device and is built for speed, simplicity, and keyboard-driven workflows. Requires macOS Screen Recording permission to capture selected regions, with no data collection, no network calls, and no accounts required.

## Screenshot

![Text Shot screenshot](assets/screenshot.png)

## Who It Is For

- Keyboard-first macOS users
- Users who extract text from videos, images, or on-screen content
- Users who prefer local-first utilities

## Key Features

- Fully local OCR processing
- Lightweight (~2 MB)
- Native macOS experience
- No login or accounts
- No runtime network access
- Fast capture-to-text workflow

## How It Works

Use your keyboard shortcut to start a quick screen selection. Text Shot reads the text inside that selected area and places it on your clipboard. You can then paste it anywhere immediately, without uploading anything to external services.

## Installation

Download the DMG from the Releases section, open it, and move Text Shot into your Applications folder. Launch the app, grant the required permissions, set your preferred shortcut (default: Cmd + Shift + 2), and start capturing text.

## Built from Source

For developers who want to build Text Shot locally.

### Prerequisites

- macOS 13 or later
- Xcode Command Line Tools (`xcodebuild`, `swift`, `codesign`, `hdiutil`)
- Node.js and npm

### Steps

1. Clone the repository.
2. Install dependencies with `npm install`.
3. Build the app with `npm run build`.
4. Launch the built app with `npm start`.
5. Run tests with `npm test`.

## Architecture

Text Shot is a native Swift menu bar app.

- `native/settings-app`: Main app runtime (menu bar item, hotkey handling, capture flow, OCR, permissions, settings UI, and confirmation toast)
- `scripts`: Build, test, typecheck, clean, and release helper scripts
- `build`: Entitlements and export configuration for packaging/signing
- `assets`: App icon and tray assets

## Agent-Assisted Development

Text Shot was built while exploring agent-assisted software development, with a GPT-5.3-Codex model. The application logic and implementation were generated through iterative prompting and system-level direction by the author, then tested in real-world usage and reviewed at a system level before release. The author assumes full responsibility for the distributed software.

This project bundles KeyboardShortcuts:
https://github.com/sindresorhus/KeyboardShortcuts
Licensed under the MIT License.

## Why I Built This

Text Shot began as a tool to eliminate repeated manual text extraction in my daily workflow while evaluating modern coding agents and frontier development tooling. The project reflects a practical exploration of agent-assisted software development alongside an understanding that strong engineering judgment and validation remain essential.

## License

MIT
