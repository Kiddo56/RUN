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
- **Active Phase:** Phase 2 Complete -> Starting Phase 3 (Stats, Goals, Gear, PRs, Effort, Share Card)
- **Last Green CI:** Run #7 (`45682801797`), commit `d50f6d2`, runner `xcode-27` (Xcode 27.1 / Swift 6.4), `TrackerCoreTests` 20/20 passed, `RUNTests` 6/6 passed, `dist/RUN.ipa` (1,025,575 bytes) downloaded locally.
- **CI Budget:** 7 / 80 runs used.
- **Next Step:** Implement Phase 3 (Stats Dashboard, streaks, trends, sliding-window PRs, Goals with progress rings & local notifications, Gear auto mileage & retirement alerts, Fitness/Fatigue trend, and MKMapSnapshotter Share Card with optional 200 m privacy trim).
