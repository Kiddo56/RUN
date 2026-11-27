# KNOWN_ISSUES.md

## CI / Simulator Notes
1. **Best-effort `RUNUITests` dropped after 2 CI failures (Phase 0 & Phase 1):**
   - Run #1 (`xcode-27`, `iPhone Duo`): `tabBars.buttons["Map"]` lookup failed on dual-display simulator layout.
   - Run #5 (`xcode-27`, `iPhone 17e`): `xcodebuild test` UI test runner hit `FBSOpenApplicationServiceErrorDomain Code=3` ("Simulator device failed to launch com.kiddo56.run").
   - Per project protocol, the best-effort `RUNUITests` CI step was removed starting in Phase 2 while `TrackerCoreTests` (`swift test`) and `RUNTests` (`xcodebuild test`) continue running on every push.

## Physical Device & Free-Signing Limitations
2. **Untested Hardware Behaviors in CI:**
   - All pure math, filtering, stats, codecs, and SwiftData flows passed automated macOS CI tests, **but no physical iPhone hardware was attached to CI**.
   - Real-world GPS lock latency, screen-lock longevity (`CLBackgroundActivitySession`), battery draw, iOS Low Power Mode throttling, audio ducking with external music apps, Bluetooth heart-rate strap (`0x180D`) pairing, and `CMAltimeter` barometer behavior must be validated outdoors using [TEST_CHECKLIST.md](TEST_CHECKLIST.md).
3. **7-Day Free Apple ID Certificate Expiry:**
   - Sideloading with a free Apple ID creates a provisioning profile valid for **7 days**. After 7 days, iOS will refuse to launch RUN until re-signed via Sideloadly (either automatically over Wi-Fi or manually over USB).
   - **NEVER delete RUN before re-signing** or local SwiftData history and `.trk` files will be erased. Always keep recent backups via **Settings > Backup, GPX & CSV**.
4. **Precise Location & Background Recording:**
   - RUN uses **When In Use** location authorization paired with `CLBackgroundActivitySession` and `UIBackgroundModes = location` (standard pattern for modern iOS workout trackers). If **Precise Location** is turned off in iOS Settings or **Low Power Mode** restricts background frequency, GPS accuracy and split timing can degrade.
5. **Phase 5 Optional Features Are Off by Default:**
   - Bluetooth Heart Rate (`bleHeartRate`), Barometric Altimeter (`barometricAltimeter`), Personal Sections (`personalSections`), and Personal Heatmap (`personalHeatmap`) start disabled in `FeatureFlags` so no extra hardware permissions are requested unless opted in under **Settings > Optional Features**.
6. **Locked-Screen Spoken Cues Need Real-Device Verification (v1.1):**
   - `audio` has been added to `UIBackgroundModes` alongside `location`, and `SpeechService` uses `.playback` + `.spokenAudio` + `.duckOthers` with explicit voice identifiers. Actual locked-screen delivery alongside third-party music/podcast apps and downloaded Enhanced/Premium voices must be verified on your physical iPhone 13.
