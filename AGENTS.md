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
- **Active Phase:** Phases 0–5 Complete (Ready for Sideloadly H2 Handoff)
- **Last Green CI:** Run #10 (`45695169866`), commit `0530879`, runner `xcode-27` (Xcode 27.1 / Swift 6.4), `TrackerCoreTests` 31/31 passed, `RUNTests` 9/9 passed, `dist/RUN.ipa` (1,500,029 bytes, `com.kiddo56.run`, v1.0.0 build 10).
- **CI Budget:** 10 / 80 runs used.
- **Next Step:** Deliver final report & H2 click-by-click install instructions, wait for user `"done"`, then provide `TEST_CHECKLIST.md` highlights and bug-report workflow.
