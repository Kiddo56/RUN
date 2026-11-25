# BUILD_LOG.md — CI Run Ledger

**Budget:** Soft limit 80 runs (`1 / 80` used).

| Run # | GitHub Run ID | Phase | Runner | Commit | Result | Notes |
|------:|--------------:|-------|--------|--------|--------|-------|
| 1 | `45669288522` | Phase 0 | `xcode-27` (Xcode 27.1 / Swift 6.4 / macOS 27.0.1) | `2e17847` | **Success** | `TrackerCoreTests` 8/8 passed, `RUNTests` 4/4 passed, unsigned `dist/RUN.ipa` (663,038 bytes) verified (`com.kiddo56.run`, v1.0.0 build 1, SHA `2e17847`). Best-effort `RUNUITests` failed once on `iPhone Duo` (`tabBars.buttons["Map"]` not found on dual-display simulator). |
