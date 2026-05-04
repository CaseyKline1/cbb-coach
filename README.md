# cbb-coach

College basketball coach simulation game, now fully Swift-native.

## Current architecture

- `CBBCoachCore` contains the native simulation, team/coach generation, and league systems.
- `iOSApp` is the SwiftUI app shell.
- `CBBCoachCLI` is a command-line entry point for quick simulation checks.
- D1 conference/team source data is bundled at `Sources/CBBCoachCore/Resources/js/d1-conferences.2026.json`.

## Quick run (CLI)

```bash
swift run CBBCoachCLI
```

## Tests

```bash
swift test
```

## TestFlight

The iOS app can be archived and uploaded with:

```bash
scripts/deploy-testflight.sh
```

The script will try to detect your signed-in Xcode team automatically. You must
have App Store Connect access for `com.casey.cbbcoach`, the app record must
already exist in App Store Connect, and you must either be signed in through
Xcode Accounts or provide an App Store Connect API key:

```bash
TEAM_ID=YOUR_TEAM_ID \
ASC_KEY_PATH=/path/to/AuthKey_KEYID.p8 \
ASC_KEY_ID=KEYID \
ASC_ISSUER_ID=ISSUER_UUID \
scripts/deploy-testflight.sh
```

Use `EXPORT_DESTINATION=export` to create an IPA locally without uploading.
The script assigns a timestamp build number by default so each TestFlight upload
is unique.

## Notes

- Legacy JavaScript engine/runtime files were removed after the Swift migration.
- League creation, scheduling, progression, standings, rankings, and persistence all run in Swift.
