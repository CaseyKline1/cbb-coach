#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage: TEAM_ID=XXXXXXXXXX scripts/deploy-testflight.sh

Archives CBBCoachApp for iOS and uploads it to App Store Connect/TestFlight.

Required:
  TEAM_ID                         Apple Developer team id used for signing.

Optional:
  PROJECT=CBBCoach.xcodeproj
  SCHEME=CBBCoachApp
  CONFIG=Release
  BUNDLE_ID=com.casey.cbbcoach
  MARKETING_VERSION=1.0
  BUILD_NUMBER=<timestamp>
  TESTFLIGHT_INTERNAL_ONLY=true   Mark upload as internal-test-only.
  EXPORT_DESTINATION=upload       Use "export" to create an IPA without uploading.
  EXPORT_PATH=build/TestFlight/export-<build>
  ARCHIVE_PATH=build/TestFlight/CBBCoachApp-<build>.xcarchive

Authentication:
  Either sign in to Xcode with an Apple Developer account that can manage
  signing and upload this app, or provide an App Store Connect API key:

  ASC_KEY_PATH=/path/to/AuthKey_ABC123DEFG.p8
  ASC_KEY_ID=ABC123DEFG
  ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000

Examples:
  TEAM_ID=X822X4U67K scripts/deploy-testflight.sh
  TEAM_ID=X822X4U67K EXPORT_DESTINATION=export scripts/deploy-testflight.sh
USAGE
  exit 0
fi

PROJECT="${PROJECT:-CBBCoach.xcodeproj}"
SCHEME="${SCHEME:-CBBCoachApp}"
CONFIG="${CONFIG:-Release}"
BUNDLE_ID="${BUNDLE_ID:-com.casey.cbbcoach}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
TEAM_ID="${TEAM_ID:-}"
TESTFLIGHT_INTERNAL_ONLY="${TESTFLIGHT_INTERNAL_ONLY:-true}"
EXPORT_DESTINATION="${EXPORT_DESTINATION:-upload}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/TestFlight/${SCHEME}-${BUILD_NUMBER}.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-build/TestFlight/export-${BUILD_NUMBER}}"

if [[ -z "$TEAM_ID" ]]; then
  echo "TEAM_ID is required. Example: TEAM_ID=X822X4U67K scripts/deploy-testflight.sh" >&2
  exit 1
fi

if [[ "$TEAM_ID" == "YOUR_TEAM_ID" || "$TEAM_ID" == "YOUR_PAID_APPLE_TEAM_ID" ]]; then
  echo "Replace TEAM_ID with your real 10-character Apple Developer Team ID." >&2
  echo "Find it in Xcode > Settings > Accounts, or Apple Developer > Membership." >&2
  exit 1
fi

if [[ "$EXPORT_DESTINATION" != "upload" && "$EXPORT_DESTINATION" != "export" ]]; then
  echo "EXPORT_DESTINATION must be either 'upload' or 'export'." >&2
  exit 1
fi

if [[ "$TESTFLIGHT_INTERNAL_ONLY" != "true" && "$TESTFLIGHT_INTERNAL_ONLY" != "false" ]]; then
  echo "TESTFLIGHT_INTERNAL_ONLY must be either 'true' or 'false'." >&2
  exit 1
fi

AUTH_ARGS=()
if [[ -n "${ASC_KEY_PATH:-}" || -n "${ASC_KEY_ID:-}" || -n "${ASC_ISSUER_ID:-}" ]]; then
  if [[ -z "${ASC_KEY_PATH:-}" || -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
    echo "Set all of ASC_KEY_PATH, ASC_KEY_ID, and ASC_ISSUER_ID, or none of them." >&2
    exit 1
  fi
  AUTH_ARGS=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"
EXPORT_OPTIONS_PLIST="$(mktemp "${TMPDIR:-/tmp}/cbb-coach-export-options.XXXXXX.plist")"
trap 'rm -f "$EXPORT_OPTIONS_PLIST"' EXIT

cat >"$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>${EXPORT_DESTINATION}</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>testFlightInternalTestingOnly</key>
  <${TESTFLIGHT_INTERNAL_ONLY}/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

echo "Archiving ${SCHEME} ${MARKETING_VERSION} (${BUILD_NUMBER})..."
ARCHIVE_CMD=(
  xcodebuild
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates
)
if [[ "${#AUTH_ARGS[@]}" -gt 0 ]]; then
  ARCHIVE_CMD+=("${AUTH_ARGS[@]}")
fi
ARCHIVE_CMD+=(
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Automatic \
  archive
)
"${ARCHIVE_CMD[@]}"

echo "Exporting archive with destination=${EXPORT_DESTINATION}..."
EXPORT_CMD=(
  xcodebuild
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates
)
if [[ "${#AUTH_ARGS[@]}" -gt 0 ]]; then
  EXPORT_CMD+=("${AUTH_ARGS[@]}")
fi
"${EXPORT_CMD[@]}"

if [[ "$EXPORT_DESTINATION" == "upload" ]]; then
  echo "Upload submitted to App Store Connect. Watch TestFlight processing for build ${MARKETING_VERSION} (${BUILD_NUMBER})."
else
  echo "IPA export complete: ${EXPORT_PATH}"
fi
