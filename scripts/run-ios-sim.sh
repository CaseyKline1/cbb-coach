#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage: scripts/run-ios-sim.sh [SIMULATOR_DEVICE_ID]

Builds, installs, and launches the iOS app in Simulator.

Defaults (override with env vars):
  PROJECT=CBBCoach.xcodeproj
  SCHEME=CBBCoachApp
  CONFIG=Debug

Examples:
  scripts/run-ios-sim.sh
  scripts/run-ios-sim.sh E78C90DD-245C-4BD3-9EA4-38B621F7DAA1
  SCHEME=CBBCoachApp CONFIG=Debug scripts/run-ios-sim.sh
USAGE
  exit 0
fi

PROJECT="${PROJECT:-CBBCoach.xcodeproj}"
SCHEME="${SCHEME:-CBBCoachApp}"
CONFIG="${CONFIG:-Debug}"
DEVICE_ID="${1:-}"

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(xcrun simctl list devices booted available | grep -Eo '[0-9A-F-]{36}' | head -n 1)"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No booted simulator found. Boot one first (Simulator.app) or pass a device ID." >&2
  exit 1
fi

open -a Simulator >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null

echo "Building $SCHEME for simulator $DEVICE_ID..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "id=$DEVICE_ID" \
  build >/tmp/${SCHEME}-xcodebuild.log

BUILD_SETTINGS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" -destination "id=$DEVICE_ID" -showBuildSettings 2>/dev/null)"
BUILD_DIR="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/ BUILT_PRODUCTS_DIR / {print $2; exit}')"
WRAPPER_NAME="$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/ WRAPPER_NAME / {print $2; exit}')"

if [[ -z "$BUILD_DIR" || -z "$WRAPPER_NAME" ]]; then
  echo "Could not locate built app. See /tmp/${SCHEME}-xcodebuild.log" >&2
  exit 1
fi

APP_PATH="$BUILD_DIR/$WRAPPER_NAME"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH. See /tmp/${SCHEME}-xcodebuild.log" >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"

echo "Installing $APP_PATH"
xcrun simctl install "$DEVICE_ID" "$APP_PATH" >/dev/null

echo "Launching $BUNDLE_ID"
LAUNCH_RESULT="$(xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID")"

echo "Done: $LAUNCH_RESULT"
