# RUN

**APP_NAME:** `RUN`  
**Bundle Identifier:** `com.kiddo56.run` *(locked — never change, so local activity history survives 7-day re-signing)*  
**Target Platform:** iOS 17.0+ (built for iPhone 13 running iOS 26.6.1, Swift 6.0)  
**Signing / Distribution Model:** Personal single-user sideload via Sideloadly from Windows (free Apple ID, 7-day certificate cycle, zero paid entitlements)

RUN is a personal, single-user, fully local iOS GPS activity and strength tracker for **Runs**, **Rides**, **Walks**, **Hikes**, **Strength**, and **Other** workouts (**Version `1.1`**). All data stays on your iPhone in versioned SwiftData (`RunSchemaV1 -> V2` lightweight migration) and compact compressed track files — there are no user accounts, no backend servers, no analytics, no social feeds, and zero third-party runtime dependencies.

---

## What's New in v1.1
- **Data Safety & Schema Migration:** Non-destructive SwiftData `VersionedSchema` (`RunSchemaV1` -> `RunSchemaV2`) + `SchemaMigrationPlan` with automated on-disk migration tests, plus Backup/Restore schema `v2` (includes strength workouts, templates, custom exercises, and exercise preferences while remaining 100% compatible with `v1` backups).
- **Full-Screen Map:** Expandable `fullScreenCover` maps on both **Record** (compact translucent HUD, confirmation-guarded Finish, `Free Pan` / `Follow` / `Heading` modes, `Standard` / `Hybrid` / `Satellite` map styles, Zoom to Whole Route, km/mile markers, downsampled polylines, camera throttling) and **Activity Detail** (pace/speed coloring + live synced route scrubber), plus Low-Power-Mode-aware **Keep Screen Awake** option.
- **More Human-Sounding Voice:** Single `SpeechService` with explicit voice identifier selection (ranking Premium > Enhanced > Default with fallback logging), pure-Swift `PhraseComposer` using natural spoken numbers and varied non-repeating templates, **Settings > Voice** with preview/rate/pitch/volume/cue triggers and the "Get a more natural voice" Apple Voices guide, `.playback` + `.spokenAudio` ducking, and `audio` background mode.
- **Fitness (Strength Training) Tab:** 133-exercise original bundled catalog (`RUN/Resources/exercises.json`), search & filters, custom exercises & personal notes, live strength workout logging with autosave/crash recovery, automatic rest timer via `SpeechService`, 9 built-in + custom scalable templates, live **PR!** badges, independent `kg`/`lb` weight unit, Epley 1RM / Top Set / Volume / Weekly Muscle Volume Swift Charts, Training Frequency calendar, Workout CSV export, and full integration into History, Calendar, Streaks, Insights, and Time/Session Goals.

---

## Implemented Features (Phases 0–5)

### Recording Core (Phase 1)
- Activity types: **Run**, **Ride**, **Walk**, **Hike**, **Other**.
- 3-2-1 start countdown (skip or cancel anytime), Start / Pause / Resume / Finish / Discard controls.
- Large-digit live telemetry: Distance, Moving Time, Elapsed Time, Current & Average Pace (or Speed for rides), Elevation Gain, GPS Signal Quality indicator (`±m`).
- Live Apple MapKit route polyline overlay with optional user-location auto-follow.
- Background & screen-lock tracking via `CLLocationUpdate.liveUpdates(.fitness)` with a held `CLBackgroundActivitySession` and `UIBackgroundModes = location` using When-In-Use permission, plus clear in-app guidance for Denied/Restricted and Reduced Accuracy states.
- Configurable GPS accuracy filtering (default `≤ 30 m`), spike rejection, rolling pace smoothing, speed-based auto-pause/resume, and 3 m elevation gain hysteresis.
- Spoken split & status voice cues (`AVSpeechSynthesizer` with `.duckOthers` audio ducking) and haptic feedback.
- Crash-safe append-only journal flushed roughly every 10 seconds and on background transitions; offers **Recover** or **Discard** on relaunch after an unexpected termination.

### History, Analytics & Editing (Phases 2 & 3)
- Reverse-chronological Activity Timeline with mini route thumbnails, search, and activity-type filters, plus an interactive monthly **Calendar** view.
- Rich **Activity Detail** screen: pace/speed-colored route polyline, Start/Finish markers, synced chart scrubbing (Elevation, Pace/Speed, and Heart Rate charts via Swift Charts), automatic split table, title/notes/gear editing, interactive **Trim**, gap-safe **Merge**, and Delete.
- **Insights Dashboard**: Week / Month / Year / All-Time breakdowns per activity type, Day & Week Streaks, Distance Trend charts, 42-day Fitness vs. 7-day Fatigue load trend, and Calorie / Effort estimates (clearly labeled as estimates).
- **Personal Records**: Sliding-window scan across your own history for fastest `1 km`, `1 mi`, `5 km`, `10 km`, `Half Marathon`, `Marathon`, Longest Distance, and Biggest Climb.
- **Goals & Gear**: Weekly/monthly distance & duration goals with circular progress rings and local `UNUserNotificationCenter` reminders; Shoe/Bike Gear Locker with auto-assignment on finish and retirement mileage notifications.
- **Share Card**: Offscreen `MKMapSnapshotter` route + stats PNG card with an option to hide the first and last 200 m around private start/end locations.

### Import / Export, Backup & Routes (Phase 4)
- **GPX 1.1** single-activity export, **Bulk GPX ZIP** archive (zero-dependency `PureZipWriter`), **CSV** summary export, and GPX track/route import via Foundation `XMLParser`.
- **Full-Fidelity Versioned Backup / Restore (`v1`)**: Exports and restores every activity (including full binary `.trk` tracks), gear item, goal, saved route, personal section, and app setting as one `.json` file via Files / Share Sheet.
- **5-Day Backup Reminder Banner**: Proactively warns in History and Settings when your last backup is older than 5 days to safeguard data ahead of the 7-day free sideload certificate expiry.
- **Routes & Follow Mode**: Interactive tap-to-draw **Route Builder**, saved route library, GPX route import/export, and live **Follow Route** guidance with remaining distance and spoken/haptic off-route alerts (> 50 m).

### Optional Extras (Phase 5 — `FeatureFlags`, All Default OFF)
Enable independently in **Settings > Optional Features** whenever needed (leaving them OFF avoids triggering Bluetooth or Motion permission prompts):
- **Bluetooth Heart-Rate Strap (`0x180D` / `0x2A37`):** CoreBluetooth scan/connect sheet, live BPM card, HR chart integration, and TRIMP effort refinement.
- **Barometric Altimeter (`CMAltimeter`):** Fuses relative barometric pressure changes onto an initial GPS elevation baseline for smoother climb tracking.
- **Personal Sections:** Drop Start and End corridor gates on Apple MapKit to automatically match and rank your own past and future single-user attempts.
- **Personal Heatmap:** Layers all of your own recorded tracks on a muted Apple MapKit canvas with activity-type filtering.

### Diagnostics
- **Settings > Diagnostics**: Rolling 2,000-entry in-app log tracking app lifecycle, location authorization changes, GPS rejections, recording milestones, recovery events, backups, and errors, exportable as `RUN-Diagnostics.txt` for troubleshooting without Xcode.

---

## Project Documentation
- [INSTALL_ON_IPHONE.md](INSTALL_ON_IPHONE.md) — Step-by-step Windows + Sideloadly install & 7-day refresh guide
- [TEST_CHECKLIST.md](TEST_CHECKLIST.md) — Real-device iPhone 13 outdoor & reliability verification checklist
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md) — CI notes, free-signing limitations, and hardware test boundaries
- [BUILD_LOG.md](BUILD_LOG.md) — Complete GitHub Actions CI run ledger (`80`-run soft budget)
- [CHANGELOG.md](CHANGELOG.md) — Phase-by-phase development changelog
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) — Dependency and tooling notices

---

## Repository Structure
- `project.yml` — XcodeGen single source of truth (`com.kiddo56.run`, Swift 6.0, iOS 17.0+, no `.pbxproj` committed)
- `Packages/TrackerCore` — Pure Swift 6 library (`Foundation` only) containing all GPS, math, stats, PR, backup, GPX/ZIP/CSV, and section/heatmap logic plus unit tests & GPX fixtures
- `RUN/` — Native SwiftUI / SwiftData / MapKit / CoreLocation / Swift Charts iOS app
- `RUNTests/` — App-level unit & persistence tests running on the CI iOS Simulator
- `scripts/generate_icon.py` — Deterministic Python generator for the Midnight Slate & Electric Teal app icon (`AppIcon-1024.png`)
- `.github/workflows/ios.yml` — Automated GitHub Actions `xcode-27` workflow testing `TrackerCore` + `RUNTests` and packaging unsigned `dist/RUN.ipa`
