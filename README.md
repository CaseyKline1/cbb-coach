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

## Notes

- Legacy JavaScript engine/runtime files were removed after the Swift migration.
- League creation, scheduling, progression, standings, rankings, and persistence all run in Swift.
