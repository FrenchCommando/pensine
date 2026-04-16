# App Store Deployment

## Current state
- App ID: `com.pensine.pensine` (both platforms)
- App icons: configured for all sizes via `flutter_launcher_icons`
- Version: defined in `pubspec.yaml`, currently `1.1.0+2`
- iOS deployment target: 13.0
- Android: uses Flutter default min/target SDK versions
- Android release signing: **not configured** (TODO in `build.gradle.kts`)
- iOS development team: **not configured**
- Screenshots + preview video: **automated** (see Screenshots & Preview Video)
- Binary upload + metadata upload: **not automated yet** (see Release Automation)

## Android (Google Play)

**Account:** Google Play Developer — $25 one-time at play.google.com/console

**Signing + upload**: see Release Automation below. Keystore is the *upload key* (Google holds the final signing key via Play App Signing).

**Build format:** AAB (`flutter build appbundle`), not APK.

**Manual store-listing tasks (one-time):**
- App name, description, category
- Content rating questionnaire (~5 min)
- Privacy policy URL (required even for local-only apps)
- First upload must go through a closed/internal test track before promoting to production
- First review takes a few days

## iOS (App Store)

**Account:** Apple Developer — $99/year at developer.apple.com (enrolled 2026-04-15)

**App Store Connect listing (partially done):**
- App name: Pensine
- Subtitle: "Visual notes with marbles"
- Bundle ID: `com.pensine.pensine`
- SKU: `pensine`
- Description, promotional text, keywords: filled in
- Marketing URL: `https://frenchcommando.github.io/pensine/site/`
- Support URL: `https://github.com/FrenchCommando/pensine/issues`
- Copyright: © 2025-2026 Martial Ren
- No sign-in required, no Game Center, no routing coverage file
- **Still needed:** screenshots/preview, build upload

**No local Mac — fully CI-based:**
- GitHub Actions macOS runners (free for public repos)
- `.github/workflows/build-ios.yml` — builds iOS (no signing) on push to main, proves the app compiles
- Release signing + TestFlight upload: see Release Automation below
- Not using `fastlane match` (solo-dev, CI-only signing → GitHub Secrets directly is simpler)

## Microsoft Store

- $19 one-time developer account
- Use `msix` pub package to build MSIX from `pubspec.yaml`
- Microsoft handles code signing
- Easiest store option for native Windows distribution

## Screenshots & Preview Video

Automated via `.github/workflows/screenshots.yml` (manual trigger).

### Screenshots
- Flutter integration test (`integration_test/screenshot_test.dart`) drives the app; `binding.takeScreenshot` captures PNGs.
- Driver `test_driver/integration_test.dart` uses `integration_test_driver_extended` with `onScreenshot`, writing PNGs to `build/screenshots/`.
- **iOS matrix:** iPhone 16 Pro Max, iPhone 16 Pro, iPad Pro 13-inch (M4) — macOS runner.
- **Android matrix:** Pixel 7, Pixel Tablet — Linux runner, api-level 35 x86_64 emulator, KVM enabled.
- Status bar overridden for store-quality frames: time 9:41, full battery, full cellular/wifi (iOS `simctl status_bar override`; Android SystemUI demo mode broadcasts).
- Screenshots uploaded as artifacts per matrix entry.

### Preview video
- Recorded **natively** — not by stitching frames.
- **iOS:** `xcrun simctl io "$UDID" recordVideo --codec=h264 build/preview-ios.mp4` runs in background while the test drives the UI; receives SIGINT on test end to finalize the mp4.
- **Android:** `adb shell screenrecord --time-limit=180 /sdcard/preview.mp4` in the emulator-runner script, pulled via `adb pull` after the test completes.
- `integration_test/preview_test.dart` is pure navigation — no `takeScreenshot` calls, no `reportData` accumulation. Timing via `linger()` pumps.

Both screenshot and preview artifacts must be downloaded and uploaded to App Store Connect / Play Console manually until the metadata lanes (see Release Automation) ship.

## Release Automation (fastlane)

**Not yet implemented.** Below is the planned shape.

### Why fastlane
- Covers build + sign + binary upload + metadata + screenshots in one DSL.
- Same lane runs locally and in CI.
- `match` is **not** used — solo-dev, CI-only signing means GitHub Secrets directly is simpler. The only moving part match solves (cert sharing across developer laptops) doesn't exist for this project.

### Layout
```
Gemfile                        # fastlane gem + deps
fastlane/
  Fastfile                     # platform :ios + :android blocks
  Appfile                      # bundle id / package name
.github/workflows/
  release.yml                  # fires on tag push v*.*.*
```

### Planned lanes
- `ios beta` — build signed ipa, upload to TestFlight via `upload_to_testflight`.
- `ios metadata` — upload App Store listing + screenshots via `deliver`.
- `android beta` — build AAB, upload to Play internal track via `upload_to_play_store(track: 'internal')`.
- `android metadata` — upload Play listing + screenshots via `upload_to_play_store(skip_upload_aab: true, ...)`.

### Phase rollout
1. Android → Play internal track (fastest feedback, no review delay).
2. iOS → TestFlight (adds cert/profile complexity; ~24h first-build review).
3. Metadata + screenshot upload (`deliver` + `supply`) once both binary lanes are green.

### iOS certificate bootstrap (one-time, Windows)
Certificates are normally generated on a Mac via Keychain Access. From Windows, use OpenSSL:

```bash
openssl genrsa -out ios_dist.key 2048
openssl req -new -key ios_dist.key -out ios_dist.csr \
  -subj "/emailAddress=martialren@gmail.com/CN=Martial Ren/C=US"
```

Upload `ios_dist.csr` to [developer.apple.com](https://developer.apple.com) → Certificates → iOS Distribution. Download the `.cer`, then:

```bash
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -inkey ios_dist.key -in distribution.pem -out ios_dist.p12
# Set an export password; this becomes IOS_DIST_CERT_PASSWORD.
base64 -w 0 ios_dist.p12 > ios_dist.p12.b64
```

Provisioning profile: create in the Apple Developer portal tied to bundle ID `com.pensine.pensine` + the distribution cert; download, base64-encode.

App Store Connect API key: App Store Connect → Users and Access → Keys. Create a key with "App Manager" role minimum. Record Key ID + Issuer ID, download the `.p8`, base64-encode it.

### Android keystore bootstrap (one-time, Windows)
```bash
keytool -genkey -v -keystore pensine-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias pensine
base64 -w 0 pensine-release.jks > pensine-release.jks.b64
```

This is the **upload key**. On first Play Console release, opt into Play App Signing so Google manages the final signing key — a compromised upload key can then be reset by Google without breaking users' upgrade paths.

### Google Play service account
1. In Google Cloud Console, create (or reuse) a project, enable **Google Play Android Developer API**.
2. Create a service account; download the JSON key.
3. In Play Console → Users and permissions → invite the service account email with "Release manager" role for this app.
4. Paste the JSON into the `PLAY_STORE_CONFIG_JSON` GitHub Secret.

### Required GitHub Secrets

**Android:**
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `PLAY_STORE_CONFIG_JSON`

**iOS:**
- `IOS_DIST_CERT_P12_BASE64`
- `IOS_DIST_CERT_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_PROVISIONING_PROFILE_NAME` — the human-readable name you gave the profile when creating it in the Apple Developer portal (not the UUID)
- `APPLE_TEAM_ID` — 10-character alphanumeric, visible at developer.apple.com → Membership
- `APPSTORE_CONNECT_API_KEY_ID`
- `APPSTORE_CONNECT_API_ISSUER_ID`
- `APPSTORE_CONNECT_API_KEY_P8_BASE64`

### Build number / versionCode strategy
- **iOS `CFBundleVersion`**: `increment_build_number` fastlane action auto-increments the Xcode project value per release.
- **Android `versionCode`**: derived from `github.run_number` at build time, passed via `--build-number` to `flutter build appbundle`. Monotonic across all runs.
- **Short version string** (`1.1.0`) stays in `pubspec.yaml`; the build number auto-increments.

### Gotchas (one-time or recurring)
- Apple Developer enrollment can take hours to days for org accounts; usually same-day for individuals.
- TestFlight first-build review is ~24h even for internal testers.
- Distribution cert + provisioning profile expire yearly — `fastlane cert`/`sigh` renew in ~5 min.
- Privacy manifest (`ios/Runner/PrivacyInfo.xcprivacy`) required for new App Store submissions (post-May 2024). Flutter 3.19+ ships a default; verify or customize.
- Google Play closed-testing requirement for personal accounts created after Nov 2023: 12+ testers running for 14+ days before first production release. Internal track is unaffected. Does not apply to organization accounts.

## Shared requirements (all stores)
- Privacy policy page — host on GitHub Pages (e.g. `frenchcommando.github.io/pensine/privacy`)
- Version bump in `pubspec.yaml` before each release
