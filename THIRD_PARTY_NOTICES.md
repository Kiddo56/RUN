# THIRD_PARTY_NOTICES.md

## App Runtime Dependencies

**RUN** (`com.kiddo56.run`) has **zero third-party runtime dependencies**.  
The compiled iOS application links strictly against Apple platform SDK frameworks supplied by iOS / Xcode:
- Swift Standard Library & Foundation
- SwiftUI & Observation
- SwiftData
- MapKit & CoreLocation
- Charts (Swift Charts)
- AVFoundation (`AVSpeechSynthesizer` audio cues) & UIKit (haptics / rendering)
- UserNotifications (`UNUserNotificationCenter` local reminders)
- UniformTypeIdentifiers
- CoreBluetooth (optional Phase 5 BLE Heart-Rate strap, feature-flagged OFF by default)
- CoreMotion (optional Phase 5 Barometric Altimeter, feature-flagged OFF by default)

Map rendering uses **Apple MapKit** directly. No third-party map tiles, analytics SDKs, crash reporters, or cloud APIs are included.

---

## Build-Time Tooling (GitHub Actions CI Only)

The following open-source tool is used strictly at build time in GitHub Actions to generate the `.xcodeproj` from `project.yml` and is **not bundled into `RUN.ipa`**:

- **XcodeGen** — Copyright © Yonas Kolb  
  Licensed under the **MIT License** (`https://github.com/yonaskolb/XcodeGen`).

---

## Sideloading Tools (User-Installed on Windows PC)

To install the unsigned `dist/RUN.ipa` onto a personal iPhone with a free Apple ID, the user separately installs:
- **Sideloadly** (`iOSGods.Sideloadly` / `sideloadly.io`) — free desktop IPA sideloader for personal free-account signing.
- **iTunes (Desktop 64-bit) & iCloud for Windows** — official Apple Inc. desktop packages downloaded from `apple.com` providing Windows USB Apple Mobile Device support.

Neither Sideloadly nor Apple's Windows utilities are embedded inside the RUN repository or compiled app.
