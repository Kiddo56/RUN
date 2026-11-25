# CHANGELOG.md

## Phase 0 — Pipeline & App Scaffold
- Initialized `RUN` (`com.kiddo56.run`) XcodeGen specification (`project.yml`) for iOS 17.0+ and Swift 6.0.
- Created `.github/workflows/ios.yml` to run `TrackerCore` SwiftPM tests, simulator `RUNTests`, best-effort `RUNUITests` screenshot capture, and unsigned `.ipa` packaging.
- Built `Packages/TrackerCore` pure-Swift foundation (`ActivityType`, `UnitSystem`, `RunFormatter`, `TrackPoint`, `FeatureFlags`, `GeoMath`) with unit tests.
- Added deterministic app icon generator (`scripts/generate_icon.py`) and asset catalog.
- Implemented Phase 0 `RUN` app: Apple MapKit view, passive location permission badge, Settings with CI version/SHA display & unit/flag controls, and rolling exportable Diagnostics log.
