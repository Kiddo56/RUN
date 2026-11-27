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
- **Active Release:** v1.1 Update — All Data Safety, Change 1 (Full-Screen Map), Change 2 (Natural Voice), and Change 3 (Fitness Section: 133 exercises, 9 templates, live logger, rest timer, PR badges, Progress charts, CSV export, History/Calendar/Goals integration) implemented; pushing Run #15 (v1.1 #5).
- **Last Green CI:** Run #11 (`46035577162`), commit `2df78d0`. (Run #14 passed 43/43 `TrackerCoreTests` and 11/11 `RUNTests` but hung on simulator teardown due to eager `AVSpeechSynthesizer` in `SpeechService.init()`; fixed via lazy/async init.)
- **CI Budget (v1.1):** 4 / 40 runs used (pushing #5).
- **Next Step:** Verify Run #15 green, download `dist/RUN-1.1.ipa`, finalize `BUILD_LOG.md` & `AGENTS.md`, and deliver v1.1 final report + H2 install handoff.
