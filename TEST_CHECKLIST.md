# RUN — Real-Device Test Checklist (iPhone 13)

CI verified all pure-Swift math/codecs (`TrackerCoreTests`), SwiftData persistence (`RUNTests`), and unsigned Release `.ipa` packaging on a simulator, **but cannot verify real GPS hardware, iOS background execution, Bluetooth sensors, or physical screen-lock behavior**. Run through this checklist outdoors on your iPhone 13 (`iOS 26.6.1`).

---

## 1. Permissions & GPS Pre-Flight
- [ ] Launch **RUN** -> tap **Record** -> verify badge shows **GPS Ready** (or prompts cleanly for **Allow While Using App** on first start).
- [ ] Confirm **Precise Location** is ON (test toggling it OFF briefly in iPhone Settings to verify the amber **Precise Location Is Off** banner + **Request Full Accuracy** button work).
- [ ] Verify Settings > About displays App Name `RUN`, Version `1.0.0`, Bundle ID `com.kiddo56.run`, and the git commit SHA.

## 2. Core Recording & Lock-Screen Background Tracking
- [ ] Start a **Walk** or **Run** -> verify **3-2-1** countdown plays haptics (and **Skip / Cancel** buttons work).
- [ ] Walk/run outdoors for **10+ minutes** with the **screen locked** in a pocket for at least 5 consecutive minutes.
- [ ] Unlock iPhone -> verify moving time, distance, current pace, elevation gain, and route polyline continued smoothly through screen lock without straight-line gaps.
- [ ] Switch to another app (e.g., Camera or Music) for 2 minutes while recording -> switch back and verify continuous recording.
- [ ] Verify **Pause -> Resume -> Finish** saves cleanly to **History** with title, notes, splits, and mini map thumbnail.

## 3. Auto-Pause, Spoken Cues & Interruptions
- [ ] Stand completely still for ~15–20 seconds mid-recording -> verify status switches to **Auto-Paused**, then resumes automatically when walking/running again.
- [ ] Play music/podcast -> pass a **1 km** (or **1 mi**) mark -> verify voice split cue ducks background audio instead of cutting it off, then restores volume.
- [ ] **Mid-recording phone call:** Accept a brief test call mid-workout, hang up after ~20 seconds, and verify GPS tracking resumes automatically.
- [ ] **Low Power Mode:** Toggle iOS Low Power Mode ON during a short test walk and check `Settings > Diagnostics` afterwards for any location gaps or error entries.

## 4. Crash Recovery
- [ ] Start a recording, record for **30+ seconds** outdoors so points flush to disk (>10 s), then **force-quit** RUN from the iOS App Switcher (swipe up).
- [ ] Reopen RUN -> verify the **Unfinished Activity Found** sheet appears with recorded point count & distance -> tap **Recover & Save Activity** and confirm it appears in **History**.

## 5. History, Charts, Editing & Share Card
- [ ] Open a recorded activity -> verify pace-colored map polyline, Start/Finish pins, Elevation & Pace/Speed charts, and Splits table.
- [ ] Drag/scrub horizontally across the Elevation or Pace chart -> confirm the highlighted cursor moves along the map route in sync.
- [ ] Test `... > Edit Details`, `... > Trim Route` (crop noisy start/end), `... > Share Activity Card` (toggle **Hide Start/End 200 m** privacy trim ON/OFF and share/save PNG).
- [ ] Toggle **Settings > Units** between **Metric** and **Imperial** -> verify values update across Record, History, Insights, and Share Card.

## 6. Stats, PRs, Goals, Gear & Routes
- [ ] Open **Insights** -> check Week/Month/Year/All-Time totals, Streaks, Personal Records, and Fitness/Fatigue chart.
- [ ] Add a weekly distance **Goal** (and optionally enable local reminder) and add a **Shoe/Bike** in **Gear Locker** marked Default -> finish an activity and confirm mileage auto-increments.
- [ ] Open **Routes > +** -> tap a few waypoints to save a route -> tap **Follow Route** -> record near and away (> 50 m) from the line to test the **Off-route** alert banner & audio cue.

## 7. Backup, GPX/CSV & Restore (Critical Before 7-Day Expiry!)
- [ ] Open **Settings > Backup, GPX & CSV > Export Full Backup** -> save the `RUN-Backup-v1-*.json` file in Apple **Files**.
- [ ] Also test **Export All GPX (ZIP)** and **Export CSV Summary**.
- [ ] Delete a dummy activity (or test restore in Merge mode) and import the `.json` backup back in to verify activities, routes, gear, goals, and settings restore cleanly.

## 8. Optional Phase 5 Extras (Enable Individually in Settings)
- [ ] Confirm all 4 toggles in **Settings > Optional Features** start **OFF** and zero Bluetooth/Motion prompts appear until enabled.
- [ ] *(If using a BLE strap)* Toggle **Bluetooth Heart-Rate Strap** ON -> open **Record > Sensors > Scan for 0x180D Straps** -> pair strap -> verify live BPM readout and saved HR chart.
- [ ] *(On hardware with barometer)* Toggle **Barometric Altimeter** ON -> confirm `ELEV GAIN (BARO)` appears during recording on stairs/hills.
- [ ] Toggle **Personal Sections** ON -> drop Start & End pins across a segment you walked/ran -> confirm your past attempt is matched and ranked under `Insights > Personal Sections`.
- [ ] Toggle **Personal Heatmap** ON -> open `Insights > Personal Heatmap` -> verify all your recorded tracks overlap on the map.

## 9. v1.1 Update Verification (Upgrade, Full-Screen Map, Natural Voice & Strength)
- [ ] **Safe Upgrade Check:** Before updating, export a backup in v1.0; install `RUN-1.1.ipa` over v1.0 (do NOT delete the app) -> open **History** and confirm ALL prior v1.0 activities, gear, goals, and routes survived intact.
- [ ] **Full-Screen Map Outdoors:** Tap the expand button on **Record** -> verify translucent HUD (time, distance, pace/speed, Pause/Resume, and confirmation-guarded Finish), cycle follow modes (`Free Pan` / `Follow` / `Heading`), toggle `Standard` / `Hybrid` / `Satellite`, tap **Zoom to whole route**, and confirm Start pin + km/mile markers render smoothly. Test the same expand button + synced route scrubber on **Activity Detail**.
- [ ] **Keep Screen Awake + Low Power Mode:** Enable **Settings > Keep Screen Awake While Recording** -> verify screen stays on while recording, then toggle iOS Low Power Mode ON and confirm the screen dims/sleeps again.
- [ ] **More Human-Sounding Voice (Screen Locked):** Open **Settings > Voice** -> if only Default voices exist, follow the "Get a more natural voice" card to download an Enhanced or Premium voice in iPhone Settings -> return to RUN and verify it appears automatically -> tap **Preview** -> lock your screen mid-run/walk and verify split/time/lap cues speak cleanly while ducking music.
- [ ] **Full Strength Workout + Rest Timer + PR Badge:** Open **Fitness > Workouts** -> start **Leg Day** (or another template) -> log weight/reps, tick a set done -> verify rest timer starts automatically and announces via `SpeechService` when finished -> beat a prior set on a second session to verify the live **PR!** badge -> tap **Finish** -> confirm the Strength workout appears in **History**, **Calendar**, **Insights**, and **Fitness > Progress** charts, and test **Workouts CSV** + **v2 Full Backup**.

---

## How to Report a Bug or Issue
If anything behaves unexpectedly on your iPhone 13:
1. Take a **screenshot** of the screen showing the issue.
2. Open **Settings > Diagnostics > Export Log** and share/save **`RUN-Diagnostics.txt`** (this captures location auth status, GPS rejection reasons, background transitions, recovery events, and errors with timestamps — without needing Xcode).
3. Note the steps you took, whether the screen was locked, and whether Low Power Mode was on.
