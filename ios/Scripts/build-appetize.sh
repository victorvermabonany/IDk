#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is required. Run this script on macOS with Xcode installed." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: XcodeGen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

if [[ ! -d Weektable.xcodeproj ]]; then
  xcodegen generate
fi

BUILD_ROOT="$PWD/build"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Weektable.app"
ARCHIVE_PATH="$BUILD_ROOT/Cove-Appetize.zip"
LOG_PATH="$BUILD_ROOT/xcodebuild.log"
RUNTIME_MODE="${COVE_RUNTIME_MODE:-DEVELOPMENT_FIXTURE}"

case "$RUNTIME_MODE" in
  DEVELOPMENT_FIXTURE)
    ;;
  STAGING_LIVE|PRODUCTION_LIVE)
    for name in COVE_API_BASE_URL COVE_PRIVACY_URL COVE_TERMS_URL COVE_SUPPORT_URL; do
      value="${!name:-}"
      if [[ ! "$value" =~ ^https:// ]]; then
        echo "error: $name must be an HTTPS URL for $RUNTIME_MODE Appetize builds." >&2
        exit 1
      fi
    done
    ;;
  *)
    echo "error: Unsupported COVE_RUNTIME_MODE: $RUNTIME_MODE" >&2
    exit 1
    ;;
esac

CONFIG_ARGS=("COVE_RUNTIME_MODE=$RUNTIME_MODE")
if [[ "$RUNTIME_MODE" != "DEVELOPMENT_FIXTURE" ]]; then
  CONFIG_ARGS+=(
    "COVE_API_BASE_URL=$COVE_API_BASE_URL"
    "COVE_PRIVACY_URL=$COVE_PRIVACY_URL"
    "COVE_TERMS_URL=$COVE_TERMS_URL"
    "COVE_SUPPORT_URL=$COVE_SUPPORT_URL"
  )
fi

mkdir -p "$BUILD_ROOT"
rm -rf "$DERIVED_DATA" "$ARCHIVE_PATH"

set -o pipefail
xcodebuild build \
  -project Weektable.xcodeproj \
  -scheme Weektable \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY='' \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  "${CONFIG_ARGS[@]}" \
  | tee "$LOG_PATH"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: Expected simulator app was not produced at $APP_PATH" >&2
  exit 1
fi

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "error: Appetize archive was not created." >&2
  exit 1
fi

echo "Created Appetize-ready artifact: $ARCHIVE_PATH"
