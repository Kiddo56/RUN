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
- **Active Release:** v1.1 Update — Pushing Change 1 fix (`FullScreenActivityMapView`) + Change 2 (More Human-Sounding Voice: `SpeechService`, `PhraseComposer`, `VoiceSettingsView`, `UIBackgroundModes: audio`) as Run #13 (v1.1 #3).
- **Last Green CI:** Run #11 (`46035577162`), commit `2df78d0`, runner `xcode-27`, `TrackerCoreTests` 34/34 passed, `RUNTests` 11/11 passed.
- **CI Budget (v1.1):** 2 / 40 runs used (pushing #3).
- **Next Step:** Verify Run #13 green (Change 1 + Change 2), then implement Change 3 (Fitness Section: 120+ exercise catalog, workout logging + autosave/recovery + rest timer, 9 templates, progress charts & PRs, timeline/calendar/insights integration).
