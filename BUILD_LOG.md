# BUILD_LOG.md — CI Run Ledger

**Budget:** Soft limit 80 runs (`5 / 80` used).

| Run # | GitHub Run ID | Phase | Runner | Commit | Result | Notes |
|------:|--------------:|-------|--------|--------|--------|-------|
| 1 | `45669288522` | Phase 0 | `xcode-27` (Xcode 27.1 / Swift 6.4 / macOS 27.0.1) | `2e17847` | **Success** | `TrackerCoreTests` 8/8 passed, `RUNTests` 4/4 passed, unsigned `dist/RUN.ipa` (663,038 bytes) verified (`com.kiddo56.run`, v1.0.0 build 1, SHA `2e17847`). Best-effort `RUNUITests` failed once on `iPhone Duo` (`tabBars.buttons["Map"]` not found on dual-display simulator). |
| 2 | `45675032917` | Phase 1 | `xcode-27` | `2db2901` | **Failed** | Swift type-checker timeout in `RecordingEngineTests.swift:135` (`(0..<120).map` closure). Fixed by expanding into an explicit loop. |
| 3 | `45675471298` | Phase 1 | `xcode-27` | `acd80b2` | **Failed** | 15/16 `TrackerCoreTests` passed; `TrackBlobCodec.recordByteCount` was 45 instead of 49 (3×Double + 6×Float + 1×UInt8 = 49 bytes). Fixed to 49. |
| 4 | `45675872280` | Phase 1 | `xcode-27` | `7cac260` | **Failed** | `TrackerCoreTests` 16/16 passed! `RecordView.swift:52` passed `RecoverySheetItem` instead of `item.session` to `recoveryPromptSheet`. Fixed + silenced unused `self` warning. |
| 5 | `45677912579` | Phase 1 | `xcode-27` (`iPhone 17e` iOS 27.2) | `220c2b0` | **Success** | `TrackerCoreTests` 16/16 passed, `RUNTests` 5/5 passed, `dist/RUN.ipa` (862,879 bytes) verified (`com.kiddo56.run`, v1.0.0, SHA `220c2b0`). Best-effort `RUNUITests` failed 2nd time (`FBSOpenApplicationServiceErrorDomain Code=3`), so `RUNUITests` is dropped starting Phase 2. |
