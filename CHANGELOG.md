# CHANGELOG.md

## Phase 4 — Import/Export, Backup/Restore & Routes
- Added `GPXCodec` (GPX 1.1 XML activity & route export/import via `XMLParser`), `PureZipWriter` (zero-dependency PKZIP bulk archive), `CSVExporter` (RFC 4180), `BackupCodec` (versioned schema `v1`), and `RouteNavigationEngine` (off-route distance & remaining distance) in `TrackerCore`.
- Built `DataTransferService` and `DataAndBackupView` for full-fidelity backup/restore, bulk GPX ZIP export, CSV export, and GPX activity import.
- Added `BackupReminderBanner` warning when the last backup is >5 days old (protecting data against 7-day free sideload signing expiry).
- Added single-activity GPX 1.1 export on `ActivityDetailView`.
- Built `RouteBuilderView` (tap map waypoints), `RoutesListView` (saved routes, GPX route import/export), and Follow Route mode on `RecordView` / `LocationRecordingService` with dashed guide polyline, remaining distance, and spoken/haptic off-route alerts.

## Phase 3 — Stats Dashboard, PRs, Goals, Gear & Share Card
- Added `StatsAggregator` (weekly/monthly/yearly/all-time totals, daily/weekly streaks, volume trend buckets, 42d/7d fitness-fatigue EMA trend, goal progress), `PersonalRecordScanner` (sliding-window fastest 1K/1Mi/5K/10K/Half/Marathon, longest distance, biggest climb), and `TrackPrivacyTrimmer` (200 m endpoint hide) with unit tests in `TrackerCore`.
- Built `InsightsDashboardView`, `PersonalRecordsView`, `GoalsView` (progress rings + local `UNUserNotificationCenter` reminders via `NotificationService`), and `GearView` (mileage tracking, default gear auto-assignment on finish, retirement alerts).
- Built `ShareCardRenderer` (`MKMapSnapshotter` + `UIGraphicsImageRenderer`) and `ShareCardSheet` with optional first/last 200 m privacy trim and `ShareLink` PNG export.

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
