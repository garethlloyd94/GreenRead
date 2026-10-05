# GreenRead — TestFlight checklist

## Already in the project
- [x] Bundle ID `com.garethlloyd.greenread`, display name "GreenRead", iPhone only, portrait, iOS 17+
- [x] App icon (Icon A, 1024 × 1024, no alpha) and a chalk launch screen
- [x] `NSCameraUsageDescription` and `NSMotionUsageDescription` (Q9 wording)
- [x] `UIBackgroundModes: audio` for the metronome
- [x] `ITSAppUsesNonExemptEncryption = NO` (no export-compliance question on upload)
- [x] `PrivacyInfo.xcprivacy`: no tracking, no data collected; UserDefaults (CA92.1) and file timestamps (C617.1, SQLite)

## On your own iPhone with a free Apple ID (no paid account)
TestFlight and the App Store need the paid Apple Developer Program, but you can install
GreenRead on your own iPhone from Xcode for free. Everything works the same.

1. Xcode → Settings → Accounts → **+** → Apple ID, and sign in.
2. Open `GreenRead.xcodeproj` → GreenRead target → Signing & Capabilities → **Team**: "Your Name (Personal Team)".
   If Xcode can't register the bundle ID, change it to something unique such as `com.garethlloyd.greenread.dev`.
3. Connect the iPhone with a cable and tap **Trust**.
4. On the iPhone: Settings → Privacy & Security → **Developer Mode** → on (the phone restarts).
5. Choose the iPhone as the run destination and press **Run** (⌘R).
6. First launch only: Settings → General → VPN & Device Management → your Apple ID → **Trust**.

Limits of a free account:
- The install **expires after 7 days**. Plug in and press Run again; saved rounds and settings are kept.
- At most **3** of your own apps on the device at once.
- No TestFlight, so you can't send builds to other people.
- Scan needs a LiDAR iPhone (12 Pro or later Pro); everything else works on any iPhone with iOS 17+.

Setting the Team edits `DEVELOPMENT_TEAM` in `project.pbxproj`. It's specific to you, so leave that line out of commits.

## Before the first TestFlight upload (paid account)
1. Xcode → GreenRead target → Signing & Capabilities → choose your Team (Automatic signing).
2. App Store Connect → My Apps → New App: iOS, name "GreenRead", bundle ID above, primary category Sports.
3. Set `MARKETING_VERSION` (0.1) and bump `CURRENT_PROJECT_VERSION` for every upload.
4. Product → Archive (scheme GreenRead, any iOS device) → Distribute App → App Store Connect → Upload.
5. App Store Connect → TestFlight → add yourself as an internal tester.

## App Privacy answers (App Store Connect)
- Data collection: **No, we do not collect data from this app.** Everything stays on the device; the only network use is YouTube video playback in the Drills player.

## Field-test pass on a real iPhone (LiDAR model for Scan)
- [ ] Quick Read: uphill reads as uphill, R→L reads as R→L (lay on a known slope)
- [ ] Quick Read: stillness threshold feels right outdoors; Flat/Aimed tick within ~1 s of laying it down
- [ ] Quick Read: AR tap-to-measure distance against a tape measure; Walk it off with your pace length
- [ ] Train: a full round saves; Stats unlock after 3 rounds
- [ ] Tempo: no drift over 3 minutes at 60 and 100 BPM; haptics line up with clicks; keeps playing when locked; stops for a phone call
- [ ] Scan: coverage fills as you walk; "Cover left side" / "Slow down" prompts make sense; poor-scan state appears below 70%
- [ ] Scan: aim matches Quick Read on the same putt (within an inch or two)
- [ ] Scan: strong sun turns on high contrast
- [ ] Drills: real YouTube IDs play inline (some creators block embedding)
- [ ] Permissions: deny camera and motion, then recover via Open Settings
- [ ] VoiceOver: every button announces sensibly; steppers adjust with swipe up/down
