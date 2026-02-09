#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/native/TextShotApp/TextShotApp.xcodeproj}"
SCHEME="${SCHEME:-Text Shot}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/dist-native/TextShot.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/dist-native/export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT_DIR/build/export-options.native.plist}"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/release}"
APP_NAME="${APP_NAME:-Text Shot}"

BUMP_MINOR=0
CUTOVER_1_0_0=0
SKIP_NOTARIZE=0
SET_VERSION=""

usage() {
  cat <<'USAGE'
Usage: bash scripts/release-native.sh [options]

Options:
  --set-version <x.y.z>         Set version explicitly
  --bump-minor                  Legacy flag (version bump is now default)
  --cutover-1-0-0               Set version to 1.0.0
  --skip-notarize               Skip notarytool submit + staple
  -h, --help                    Show this help
USAGE
}

fail() {
  echo "release-native: $*" >&2
  exit 1
}

validate_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

bump_release_version() {
  local major minor patch
  IFS='.' read -r major minor patch <<<"$1"
  if (( minor >= 9 )); then
    echo "$((major + 1)).0.0"
    return
  fi

  echo "${major}.$((minor + 1)).0"
}

read_package_version() {
  /usr/bin/awk -F'"' '/"version"/ {print $4; exit}' "$ROOT_DIR/package.json"
}

set_package_version() {
  local version="$1"
  npm version "$version" --no-git-tag-version >/dev/null
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --set-version)
      SET_VERSION="${2:-}"
      shift 2
      ;;
    --bump-minor)
      BUMP_MINOR=1
      shift
      ;;
    --cutover-1-0-0)
      CUTOVER_1_0_0=1
      shift
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

if [[ "$BUMP_MINOR" -eq 1 && -n "$SET_VERSION" ]]; then
  fail "--bump-minor and --set-version cannot be combined"
fi

if [[ "$CUTOVER_1_0_0" -eq 1 && ( "$BUMP_MINOR" -eq 1 || -n "$SET_VERSION" ) ]]; then
  fail "--cutover-1-0-0 cannot be combined with --bump-minor or --set-version"
fi

CURRENT_VERSION="$(read_package_version)"
validate_semver "$CURRENT_VERSION" || fail "Invalid current version in package.json: $CURRENT_VERSION"

TARGET_VERSION="$CURRENT_VERSION"
if [[ -n "$SET_VERSION" ]]; then
  validate_semver "$SET_VERSION" || fail "Invalid --set-version value: $SET_VERSION"
  TARGET_VERSION="$SET_VERSION"
elif [[ "$CUTOVER_1_0_0" -eq 1 ]]; then
  TARGET_VERSION="1.0.0"
else
  TARGET_VERSION="$(bump_release_version "$CURRENT_VERSION")"
fi

if [[ "$TARGET_VERSION" != "$CURRENT_VERSION" ]]; then
  echo "Updating version: $CURRENT_VERSION -> $TARGET_VERSION"
  set_package_version "$TARGET_VERSION"
fi

rm -rf "$ROOT_DIR/dist-native"
mkdir -p "$ROOT_DIR/dist-native" "$RELEASE_DIR"

if [[ -d "$PROJECT_PATH" ]]; then
  [[ -f "$EXPORT_OPTIONS_PLIST" ]] || fail "Missing export options plist: $EXPORT_OPTIONS_PLIST"

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    clean archive

  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

  APP_PATH="$(find "$EXPORT_PATH" -maxdepth 2 -type d -name "*.app" | head -n 1)"
else
  bash "$ROOT_DIR/scripts/build-settings-app.sh"
  APP_PATH="$ROOT_DIR/bin/Text Shot.app"
fi

[[ -d "$APP_PATH" ]] || fail "No app bundle found: $APP_PATH"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$APP_PATH" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait

    xcrun stapler staple "$APP_PATH"
  else
    echo "Skipping notarization because Apple credentials are not set"
  fi
fi

DMG_NAME="$APP_NAME-$TARGET_VERSION.dmg"
DMG_PATH="$ROOT_DIR/dist-native/$DMG_NAME"
STAGING_DIR="$(mktemp -d "$ROOT_DIR/dist-native/dmg-staging.XXXXXX")"
VOLUME_NAME="$APP_NAME Installer"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

cp -R "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

find "$RELEASE_DIR" -maxdepth 1 -type f -name "$APP_NAME-*.dmg" -delete
find "$RELEASE_DIR" -maxdepth 1 -type f -name "$APP_NAME-*.dmg.sha256" -delete

cp -f "$DMG_PATH" "$RELEASE_DIR/$DMG_NAME"
shasum -a 256 "$RELEASE_DIR/$DMG_NAME" > "$RELEASE_DIR/$DMG_NAME.sha256"

echo "Release artifact ready: $RELEASE_DIR/$DMG_NAME"
echo "Checksum ready: $RELEASE_DIR/$DMG_NAME.sha256"
