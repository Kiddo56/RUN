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
- **Active Phase:** Phase 0 Complete -> Starting Phase 1 (Recording Core)
- **Last Green CI:** Run #1 (`45669288522`), commit `2e17847`, runner `xcode-27` (Xcode 27.1 / Swift 6.4), `dist/RUN.ipa` (663,038 bytes) downloaded locally.
- **Note for Phase 1 CI:** Avoid selecting dual-display `iPhone Duo` simulator in `.github/workflows/ios.yml` so standard iPhone tab bar & `simctl io screenshot` work cleanly on `RUNUITests` (if `RUNUITests` still fails on second try, drop UI tests step per protocol).
- **Next Step:** Implement Phase 1 (Recording Core: pure `TrackerCore` GPS filtering, pace smoothing, moving time, elevation gain, splits, track binary codec + 4 GPX fixtures + unit tests; `LocationRecordingService` with `CLLocationUpdate.liveUpdates()` + `CLBackgroundActivitySession`, 3-2-1 countdown, live map & metrics, auto-pause, speech/haptic cues, 10s crash-recovery journal).
