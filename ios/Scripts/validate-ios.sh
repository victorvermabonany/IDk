#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen"; exit 1; }
xcodegen generate

xcodebuild \
  -project Weektable.xcodeproj \
  -scheme Weektable \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  clean test

xcodebuild \
  -project Weektable.xcodeproj \
  -scheme Weektable \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  build

xcodebuild \
  -project Weektable.xcodeproj \
  -scheme Weektable \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  build

