# KNOWN_ISSUES.md

## CI / Simulator Notes
1. **Best-effort `RUNUITests` dropped after 2 CI failures (Phase 0 & Phase 1):**
   - Run #1 (`xcode-27`, `iPhone Duo`): `tabBars.buttons["Map"]` lookup failed on dual-display simulator layout.
   - Run #5 (`xcode-27`, `iPhone 17e`): `xcodebuild test` UI test runner hit `FBSOpenApplicationServiceErrorDomain Code=3` ("Simulator device failed to launch com.kiddo56.run").
   - Per project protocol, the best-effort `RUNUITests` CI step was removed starting in Phase 2 while `TrackerCoreTests` (`swift test`) and `RUNTests` (`xcodebuild test`) continue running on every push.

- Any feature failing after 8 CI attempts will be placed behind a `FeatureFlags` toggle (default OFF) and documented here.
