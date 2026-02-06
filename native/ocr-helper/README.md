# ocr-helper

Swift CLI helper for local OCR using Apple Vision.

## Build

```bash
swift build -c release --arch arm64
swift build -c release --arch x86_64
```

Use `scripts/build-helper.sh` from the repo root to build and lipo into a universal binary.
