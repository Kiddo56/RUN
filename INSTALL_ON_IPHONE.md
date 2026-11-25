# Installing RUN on Your iPhone (Windows + Sideloadly)

This guide explains how to install **RUN** (`dist/RUN.ipa`, Bundle ID `com.kiddo56.run`) onto your iPhone 13 using a free Apple ID and a Windows PC — no Mac or Xcode required.

> **Important:** Free Apple ID signatures expire every **7 days**. Because `com.kiddo56.run` never changes, reinstalling over the top with the same Apple ID keeps all of your recorded runs, routes, gear, and goals intact — **as long as you never delete the app first**.

---

## Before You Start (PC Setup — One Time Only)

Apple's device drivers are required on Windows before Sideloadly can see your iPhone over USB. Make sure you use the **desktop web installers from `apple.com`**, **not** the Microsoft Store versions:

1. **Install Desktop iTunes (64-bit) & Desktop iCloud**
   - Installers are saved inside `dist\installers\` (downloaded directly from `apple.com` and digitally signed by Apple Inc.).
   - Double-click **`iTunes64Setup.exe`** and click **Yes** when Windows asks for administrator permission. Finish the installer.
   - Double-click **`iCloudSetup.exe`**, click **Yes** if prompted, finish the installer, and restart your PC if requested.
   - Open **iCloud for Windows** once and sign in with your Apple ID.
2. **Install Sideloadly**
   - Use Sideloadly (installed via `winget install iOSGods.Sideloadly` or `SideloadlySetup64.exe` from `sideloadly.io`).
   - Open **Sideloadly** once after installation completes.

> **Privacy & Account Tip:** If you already have a secondary/spare Apple ID, you can use it for Sideloadly instead of your main Apple ID. Never share your Apple ID password or 2FA codes with anyone.

---

## One-Time iPhone 13 Prep (iOS 17–26+)

3. **Turn On Developer Mode** (required once on iOS 16+ / iOS 26.6.1 for sideloaded apps):
   - On your iPhone, open **Settings > Privacy & Security**.
   - Scroll down to **Developer Mode**, toggle it **On**, and tap **Restart** when prompted.
   - After the iPhone restarts and unlocks, confirm **Turn On** on the Developer Mode popup and enter your iPhone passcode.

---

## Installing `RUN.ipa`

4. **Connect Your iPhone 13 to Windows**:
   - Plug your iPhone into your PC using a Lightning/USB cable.
   - Unlock the iPhone and tap **Trust This Computer** (enter your passcode).
   - If you also want iTunes to confirm the connection, open iTunes once and check that the small iPhone icon appears near the top-left.
5. **Sign & Install with Sideloadly**:
   - Open **Sideloadly** on Windows.
   - Confirm your iPhone appears in the **iDevice** dropdown.
   - Drag and drop **`dist\RUN.ipa`** onto the **IPA** box in Sideloadly (or click the IPA icon and browse to `dist\RUN.ipa`).
   - Enter your **Apple ID email** in the **Apple Account** box (keep bundle ID untouched so it remains `com.kiddo56.run`).
   - Click **Start**.
   - If prompted on first use, enter your Apple ID password and approve the **6-digit Two-Factor Authentication (2FA)** code shown on your iPhone.
   - Wait until the Sideloadly status bar says **`Done.`** and the teal **RUN** icon appears on your iPhone Home Screen.
6. **Trust Your Free Developer Certificate on iPhone**:
   - Open **Settings > General > VPN & Device Management** (below VPN).
   - Under **Developer App**, tap your Apple ID email.
   - Tap **Trust "<your Apple ID>"**, then confirm **Trust**.
7. **First Launch Permissions**:
   - Open **RUN**.
   - When asked for location permission, choose **Allow While Using App**.
   - Ensure **Precise Location** is switched **ON** (green) for accurate routes, splits, and elevation.

---

## Keeping RUN Running Past 7 Days (Weekly Re-Sign)

With a free Apple ID, iOS stops opening the app 7 days after signing until you refresh it:

### Option A: Sideloadly Wi-Fi Auto-Refresh (Recommended)
1. Enable **Wi-Fi Sync** for your iPhone once inside desktop **iTunes** (plug in via USB -> click the iPhone icon -> Summary -> check **Sync with this iPhone over Wi-Fi** -> Apply).
2. In Sideloadly's daemon/tray icon (Windows system tray near the clock), verify your iPhone is listed for **Automatic Refresh**. While your PC and iPhone are on the same Wi-Fi network, Sideloadly refreshes the 7-day signature automatically before it expires.

### Option B: Manual Re-Sign Over the Existing App
1. **Before Day 7 expires**, export a safety backup in the app: **Settings > Backup, GPX & CSV > Export Full Backup** and save it to **Files** (iCloud Drive / On My iPhone). RUN reminds you automatically after 5 days.
2. Plug your iPhone into Windows, open **Sideloadly**, drop **`dist\RUN.ipa`** in again, enter the **same Apple ID** (keeping Bundle ID `com.kiddo56.run`), and click **Start**.
3. **NEVER delete RUN from your iPhone before re-signing** — deleting removes the app's local SwiftData database and track files.

---

## Switching Back to Private Repo on GitHub (Optional)

While building, keeping `Kiddo56/RUN` **Public** gave free unlimited macOS CI minutes. Now that `dist/RUN.ipa` is built, you can make the repo private anytime:
1. Open `https://github.com/Kiddo56/RUN/settings` on GitHub.
2. Scroll to **Danger Zone > Change repository visibility**.
3. Click **Change visibility > Make private** and confirm.
