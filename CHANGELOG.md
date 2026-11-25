# CHANGELOG.md

## Phase 2 — History, Calendar, Detail & Editing
- Added `TrackChartBuilder` and `TrackEditor` (trim and gap-safe chronological merge) with unit tests in `TrackerCore`.
- Upgraded `HistoryListView` with Timeline / Calendar switcher, activity type pills, search, and navigation to `ActivityDetailView`.
- Built `ActivityCalendarView` monthly grid with daily indicators and month totals.
- Built `ActivityDetailView` with pace/speed-colored MapKit route polylines, Start/Finish markers, interactive synchronized Swift Charts (`Elevation`, `Pace/Speed`, `Heart Rate`) with map scrubbing highlight, splits table, and Edit / Trim / Merge / Delete tools.
- Dropped twice-failed best-effort `RUNUITests` step from `.github/workflows/ios.yml` per protocol.

## Phase 1 — Recording Core
- Expanded `TrackerCore` with `GPSFilter`, `PaceSmoother`, `MovingTimeEngine`, `ElevationEngine` (3 m hysteresis), `SplitCalculator`, `TrackBlobCodec` (compact zlib binary format), `JournalLineCodec`, `RecordingSessionEngine`, `TrackAnalyzer`, and `BasicGPXReader`.
- Added 4 GPX test fixtures (`steady_run.gpx`, `road_ride.gpx`, `noisy_urban_gps.gpx`, `stop_and_go_walk.gpx`) and unit tests.
- Defined the full SwiftData schema (`SDActivity`, `SDGear`, `SDGoal`, `SDSavedRoute`, `SDSection`) and `TrackFileStore` single-blob + 10s crash-recovery journal.
- Implemented `LocationRecordingService` (`CLLocationUpdate.liveUpdates(.fitness)` + `CLBackgroundActivitySession`), `AudioHapticCueService` (`AVSpeechSynthesizer` with audio ducking), `RecordView` (3-2-1 countdown, live map polyline, telemetry, auto-pause, permission/reduced-accuracy guidance, recovery prompt), and `HistoryListView`.

## Phase 0 — Pipeline & App Scaffold
- Initialized `RUN` (`com.kiddo56.run`) XcodeGen specification (`project.yml`) for iOS 17.0+ and Swift 6.0.
- Created `.github/workflows/ios.yml` to run `TrackerCore` SwiftPM tests, simulator `RUNTests`, best-effort `RUNUITests` screenshot capture, and unsigned `.ipa` packaging.
- Built `Packages/TrackerCore` pure-Swift foundation (`ActivityType`, `UnitSystem`, `RunFormatter`, `TrackPoint`, `FeatureFlags`, `GeoMath`) with unit tests.
- Added deterministic app icon generator (`scripts/generate_icon.py`) and asset catalog.
- Implemented Phase 0 `RUN` app: Apple MapKit view, passive location permission badge, Settings with CI version/SHA display & unit/flag controls, and rolling exportable Diagnostics log.
