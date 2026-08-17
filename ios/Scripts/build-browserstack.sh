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
DERIVED_DATA="$BUILD_ROOT/BrowserStackDerivedData"
PACKAGE_ROOT="$BUILD_ROOT/browserstack-package"
IPA_PATH="$BUILD_ROOT/Cove-BrowserStack.ipa"
LOG_PATH="$BUILD_ROOT/browserstack-xcodebuild.log"
RUNTIME_MODE="${COVE_RUNTIME_MODE:-PRODUCTION_LIVE}"

if [[ "$RUNTIME_MODE" != "STAGING_LIVE" && "$RUNTIME_MODE" != "PRODUCTION_LIVE" ]]; then
  echo "error: BrowserStack device builds require STAGING_LIVE or PRODUCTION_LIVE." >&2
  exit 1
fi

if [[ "$RUNTIME_MODE" == "PRODUCTION_LIVE" ]]; then
  BUILD_CONFIGURATION=Release
else
  BUILD_CONFIGURATION=Debug
fi
APP_PATH="$DERIVED_DATA/Build/Products/${BUILD_CONFIGURATION}-iphoneos/Weektable.app"

for name in COVE_API_BASE_URL COVE_PRIVACY_URL COVE_TERMS_URL COVE_SUPPORT_URL; do
  value="${!name:-}"
  if [[ ! "$value" =~ ^https:// ]]; then
    echo "error: $name must be an HTTPS URL for BrowserStack device builds." >&2
    exit 1
  fi
done

mkdir -p "$BUILD_ROOT"
rm -rf "$DERIVED_DATA" "$PACKAGE_ROOT" "$IPA_PATH"

set -o pipefail
xcodebuild build \
  -project Weektable.xcodeproj \
  -scheme Weektable \
  -configuration "$BUILD_CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY='' \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  "COVE_RUNTIME_MODE=$RUNTIME_MODE" \
  "COVE_API_BASE_URL=$COVE_API_BASE_URL" \
  "COVE_PRIVACY_URL=$COVE_PRIVACY_URL" \
  "COVE_TERMS_URL=$COVE_TERMS_URL" \
  "COVE_SUPPORT_URL=$COVE_SUPPORT_URL" \
  | tee "$LOG_PATH"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: Expected physical-device app was not produced at $APP_PATH" >&2
  exit 1
fi

EXECUTABLE_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist")
EXECUTABLE_PATH="$APP_PATH/$EXECUTABLE_NAME"
if [[ ! -f "$EXECUTABLE_PATH" ]]; then
  echo "error: Missing application executable at $EXECUTABLE_PATH" >&2
  exit 1
fi

ARCHS=$(xcrun lipo -archs "$EXECUTABLE_PATH")
if [[ " $ARCHS " != *" arm64 "* ]]; then
  echo "error: BrowserStack IPA must contain an arm64 physical-device executable; found: $ARCHS" >&2
  exit 1
fi

if ! xcrun vtool -show-build "$EXECUTABLE_PATH" | grep -Eq 'platform +IOS'; then
  echo "error: Executable is not built for the physical iOS platform." >&2
  exit 1
fi

mkdir -p "$PACKAGE_ROOT/Payload"
/usr/bin/ditto "$APP_PATH" "$PACKAGE_ROOT/Payload/Weektable.app"
(
  cd "$PACKAGE_ROOT"
  /usr/bin/zip -qry "$IPA_PATH" Payload
)

if [[ ! -f "$IPA_PATH" ]]; then
  echo "error: BrowserStack IPA was not created." >&2
  exit 1
fi

/usr/bin/unzip -tq "$IPA_PATH" >/dev/null
if ! /usr/bin/unzip -Z1 "$IPA_PATH" | grep -q '^Payload/Weektable\.app/Info\.plist$'; then
  echo "error: IPA does not contain Payload/Weektable.app/Info.plist." >&2
  exit 1
fi

echo "Created BrowserStack App Live artifact: $IPA_PATH"
echo "The app is intentionally packaged without Apple credentials; BrowserStack App Live re-signs uploaded iOS apps for its devices."
