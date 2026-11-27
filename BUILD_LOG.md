# BUILD_LOG.md — CI Run Ledger

**Budget:** v1.0 used `10 / 80` runs. **v1.1 Update Budget:** Soft limit 40 runs (`1 / 40` used).

| Run # | GitHub Run ID | Phase | Runner | Commit | Result | Notes |
|------:|--------------:|-------|--------|--------|--------|-------|
| 1 | `45669288522` | Phase 0 | `xcode-27` (Xcode 27.1 / Swift 6.4 / macOS 27.0.1) | `2e17847` | **Success** | `TrackerCoreTests` 8/8 passed, `RUNTests` 4/4 passed, unsigned `dist/RUN.ipa` (663,038 bytes) verified (`com.kiddo56.run`, v1.0.0 build 1, SHA `2e17847`). Best-effort `RUNUITests` failed once on `iPhone Duo` (`tabBars.buttons["Map"]` not found on dual-display simulator). |
| 2 | `45675032917` | Phase 1 | `xcode-27` | `2db2901` | **Failed** | Swift type-checker timeout in `RecordingEngineTests.swift:135` (`(0..<120).map` closure). Fixed by expanding into an explicit loop. |
| 3 | `45675471298` | Phase 1 | `xcode-27` | `acd80b2` | **Failed** | 15/16 `TrackerCoreTests` passed; `TrackBlobCodec.recordByteCount` was 45 instead of 49 (3×Double + 6×Float + 1×UInt8 = 49 bytes). Fixed to 49. |
| 4 | `45675872280` | Phase 1 | `xcode-27` | `7cac260` | **Failed** | `TrackerCoreTests` 16/16 passed! `RecordView.swift:52` passed `RecoverySheetItem` instead of `item.session` to `recoveryPromptSheet`. Fixed + silenced unused `self` warning. |
| 5 | `45677912579` | Phase 1 | `xcode-27` (`iPhone 17e` iOS 27.2) | `220c2b0` | **Success** | `TrackerCoreTests` 16/16 passed, `RUNTests` 5/5 passed, `dist/RUN.ipa` (862,879 bytes) verified (`com.kiddo56.run`, v1.0.0, SHA `220c2b0`). Best-effort `RUNUITests` failed 2nd time (`FBSOpenApplicationServiceErrorDomain Code=3`), so `RUNUITests` is dropped starting Phase 2. |
| 6 | `45682338928` | Phase 2 | `xcode-27` | `b4faf9f` | **Failed** | 19/20 `TrackerCoreTests` passed; `TrackAnalyzer.summarize` treated `TrackPoint.speed == 0` as stationary instead of falling back to segment distance/time speed (`p1.speed > 0 ? p1.speed : segSpeed`). Fixed. |
| 7 | `45682801797` | Phase 2 | `xcode-27` (`iPhone 17e` iOS 27.2) | `d50f6d2` | **Success** | `TrackerCoreTests` 20/20 passed, `RUNTests` 6/6 passed, `dist/RUN.ipa` (1,025,575 bytes) verified (`com.kiddo56.run`, v1.0.0, SHA `d50f6d2`). Duration 14m37s. |
| 8 | `45686362203` | Phase 3 | `xcode-27` (`iPhone 17e` iOS 27.2) | `0aa10d5` | **Success** | `TrackerCoreTests` 23/23 passed, `RUNTests` 7/7 passed, `dist/RUN.ipa` (1,200,656 bytes) verified (`com.kiddo56.run`, v1.0.0, SHA `0aa10d5`). Duration 18m33s. |
| 9 | `45690675198` | Phase 4 | `xcode-27` (`iPhone 17e` iOS 27.2) | `e25cde3` | **Success** | `TrackerCoreTests` 28/28 passed, `RUNTests` 8/8 passed, `dist/RUN.ipa` (1,377,246 bytes) verified (`com.kiddo56.run`, v1.0.0, SHA `e25cde3`). Duration 15m21s. |
| 10 | `45695169866` | Phase 5 | `xcode-27` (`iPhone 17e` iOS 27.2) | `0530879` | **Success** | `TrackerCoreTests` 31/31 passed, `RUNTests` 9/9 passed, `dist/RUN.ipa` (1,500,029 bytes) verified (`com.kiddo56.run`, v1.0.0 build 10, SHA `0530879`, `MinimumOSVersion` 17.0). Duration 15m25s. |
| 11 (v1.1 #1) | `46035577162` | v1.1 Data Safety | `xcode-27` (`iPhone 17e` iOS 27.2) | `2df78d0` | **Success** | `TrackerCoreTests` 34/34 passed, `RUNTests` 11/11 passed (incl. on-disk SwiftData v1->v2 migration & v2 backup), `RUN-1.1.ipa` built (`com.kiddo56.run`, v1.1). Duration 13m33s. |
