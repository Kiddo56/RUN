# AGENTS.md — Working Context for RUN

## Locked Project Configuration
- **App Name:** `RUN`
- **Repository:** `https://github.com/Kiddo56/RUN` (`public`)
- **Bundle Identifier:** `com.kiddo56.run` (**IMMUTABLE — NEVER CHANGE**)
- **Deployment Target:** iOS 17.0 (User device: iPhone 13, iOS 26.6.1)
- **Signing Model:** Free Apple ID sideloaded via Sideloadly (7-day re-sign cycle). Zero paid entitlements (no HealthKit, App Groups, CloudKit, Live Activities, push notifications).
- **Local Directory:** `C:\Users\elvis\Projects\RUN`

## Architecture & Conventions
- **Swift 6 Strict Concurrency:** Keep `@Observable` models and views `@MainActor`; keep `TrackerCore` types `Sendable`.
- **Pure Logic Isolation:** Put all math, GPS filtering, smoothing, elevation gain, splits, PRs, effort, GPX/CSV/backup IO in `Packages/TrackerCore` (`Foundation` only — NO `CoreLocation`, `SwiftUI`, `UIKit`).
- **XcodeGen Only:** Never commit `.xcodeproj` or hand-edit `.pbxproj`. Modify `project.yml` instead.
- **Clean-Room Palette:** Midnight Slate (`#0B132B`), Electric Teal (`#00D4E5`), Emerald (`#10B981`), Amber (`#F59E0B`), Coral (`#EF4444`), Violet (`#8B5CF6`). Never use orange. Never use SF Symbols in the app icon.
- **Diagnostics:** Log lifecycle, auth, location, recording, recovery, backup, and errors to `DiagnosticsLogger.shared` (rolling 2,000 entries, exportable as `.txt`).

## Current State
- **Active Phase:** Phase 3 Complete -> Starting Phase 4 (Import/Export, Backup/Restore, Routes & Follow Route)
- **Last Green CI:** Run #8 (`45686362203`), commit `0aa10d5`, runner `xcode-27` (Xcode 27.1 / Swift 6.4), `TrackerCoreTests` 23/23 passed, `RUNTests` 7/7 passed, `dist/RUN.ipa` (1,200,656 bytes) downloaded locally.
- **CI Budget:** 8 / 80 runs used.
- **Next Step:** Implement Phase 4 (GPX 1.1 single & bulk export, CSV export, full-fidelity versioned Backup & Restore with >5-day banner, Foundation XMLParser GPX activity/route importer, tap-waypoint Route Builder, and Follow Route mode with off-route alert).
