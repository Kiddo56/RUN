# RUN

**APP_NAME:** `RUN`  
**Bundle Identifier:** `com.kiddo56.run` (locked — never change, so app data survives 7-day Sideloadly re-signs)  
**Target Platform:** iOS 17.0+ (built for iPhone 13 running iOS 26.6.1)

RUN is a single-user, fully local iOS GPS activity tracker for runs, rides, walks, hikes, and custom sessions. There are no accounts, no cloud sync, no servers, no third-party fitness APIs, and no third-party runtime dependencies.

## Features (Planned Across Phases 0–5)
- **Phase 0 (Current):** Automated macOS GitHub Actions CI + unsigned `.ipa` packaging, Apple MapKit home screen, Settings with build/commit metadata, and rolling exportable Diagnostics log.
- **Phase 1:** Full GPS recording core (`CLLocationUpdate.liveUpdates()` + `CLBackgroundActivitySession`), 3-2-1 countdown, live metrics & polyline, auto-pause/resume, voice/haptic cues, crash-safe track journaling & recovery.
- **Phase 2:** Activity timeline with route thumbnails, calendar month view, pace/speed-colored map detail, synced interactive charts, splits, trim/merge/edit/delete.
- **Phase 3:** Aggregated stats, streaks, sliding-window Personal Records, weekly/monthly goals, gear mileage & retirement alerts, effort & fitness/fatigue estimates, privacy-trimmed Share Cards.
- **Phase 4:** GPX 1.1 import/export, CSV export, full-fidelity versioned backup/restore with >5-day backup reminder banner, interactive Route Builder, and Follow Route mode with off-route alerts.
- **Phase 5 (Feature-Flagged, default OFF):** Optional Bluetooth Heart-Rate strap (`0x180D`), Barometric Altimeter (`CMAltimeter`), Personal Sections, and Personal Heatmap.

## Project Structure
- `project.yml` — XcodeGen single source of truth (no `.pbxproj` committed)
- `Packages/TrackerCore` — Pure Swift 6 library (`Foundation` only) housing all algorithms, codecs, and tests
- `RUN/` — SwiftUI / SwiftData / MapKit / CoreLocation iOS application
- `RUNTests/` & `RUNUITests/` — App unit and simulator UI smoke tests
- `scripts/generate_icon.py` — Deterministic Python script generating app icons and asset colors
- `.github/workflows/ios.yml` — macOS CI pipeline building tests and unsigned `dist/RUN.ipa`
