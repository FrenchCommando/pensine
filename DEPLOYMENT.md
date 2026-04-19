# App Store Deployment

## Current state
- App ID: `com.frenchcommando.pensine` (both platforms)
- App icons: configured for all sizes via `flutter_launcher_icons`
- Version: defined in `pubspec.yaml`, currently `1.1.0+2`
- iOS deployment target: 13.0
- Android: uses Flutter default min/target SDK versions
- Android release signing: `build.gradle.kts` reads from `android/key.properties` (written by CI from secrets); keystore + secrets pending first setup pass (2026-04-18)
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

**App Store Connect listing:**
- ✅ App name: Pensine
- ✅ Subtitle: "Visual notes with marbles"
- ✅ Bundle ID: `com.frenchcommando.pensine`
- ✅ SKU: `pensine`
- ✅ Description, promotional text, keywords
- ✅ Marketing URL: `https://frenchcommando.github.io/pensine/site/`
- ✅ Support URL: `https://github.com/FrenchCommando/pensine/issues`
- ✅ Copyright: © 2025-2026 Martial Ren
- ✅ No sign-in required, no Game Center, no routing coverage file
- ✅ Content Rights: filled in
- ✅ Age Rating: questionnaire answered
- ✅ Price: Free (tier 0)
- ⚠️ Screenshots: manually uploaded using partial CI results (6.9" iPhone + iPad); screenshot workflow still not fully working
- ✅ Build: first TestFlight build uploaded and submitted for review (2026-04-18, build #7)
- ✅ Privacy Policy URL: `https://frenchcommando.github.io/pensine/privacy.html` (set in App Privacy section)
- ✅ App Privacy nutrition label: "No, we do not collect data from this app" (Pensine is local-only; no plugin collects data)
- ✅ Export compliance: declared via `ITSAppUsesNonExemptEncryption = false` in Info.plist — skips the per-upload questionnaire
- ⬜ App Clip: not applicable (no single-task flow suited to App Clip)

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

Automated via `.github/workflows/screenshots.yml` (manual trigger). All multi-step orchestration lives in shell scripts under `tool/` because the `reactivecircus/android-emulator-runner` action runs each YAML `script:` line as a separate `sh -c`, fragmenting variables.

Test helpers (`settle`, `linger`, `scrollTo`) are shared between screenshot and preview tests in `integration_test/test_helpers.dart`.

### Screenshots
- Test: `integration_test/screenshot_test.dart`. Driver: `test_driver/integration_test.dart` (uses `integration_test_driver_extended` with `onScreenshot`).
- Status-bar polish (9:41 clock, full battery, full signal) applied via `tool/setup_ios_status_bar.sh` / `tool/setup_android_status_bar.sh`.
- Both platforms use **host-driven capture** via `tool/screenshot_server.py`. `binding.takeScreenshot` and `convertFlutterSurfaceToImage` both wait for Flutter to go idle, which never happens because `MarbleBoard`'s physics ticker calls `setState` every frame. The test POSTs `/screenshot/<name>` to the server; the server shells out to the platform's native capture and writes `build/screenshots/<name>.png` synchronously, so a 200 response is the test's signal to advance. The test also flips `debugPauseMarblePhysics` around each capture so marbles don't drift mid-frame.
- **iOS matrix** (iPhone 16 Pro Max for the required 6.9" slot, iPad Pro 13-inch M4 for the required iPad slot) — `tool/run_ios_screenshot_test.sh`:
  - Starts the server in `--mode ios` on plain HTTP `127.0.0.1:8765` (sim shares host loopback, so no cert needed).
  - Server runs `xcrun simctl io <udid> screenshot --type=png <out>`.
  - Boot via `tool/boot_ios_simulator.sh "<device>"` (writes `UDID` to `$GITHUB_ENV`).
  - App Store Connect's 6.5" slot is a fallback for 6.9" and not needed when 6.9" is filled; 6.1" (iPhone 16 Pro native) is optional.
- **Android matrix** (Pixel 7, Pixel Tablet, api-level 35 x86_64) — `tool/run_screenshot_test.sh`:
  - Mints a fresh self-signed cert+key per run with `openssl` (no checked-in secrets).
  - Server runs in `--mode android` over HTTPS on `0.0.0.0:8765` because the test reaches the host via `10.0.2.2`, which requires TLS.
  - Cert passed to the test as base64 via `--dart-define=SCREENSHOT_CERT_B64`; test pins trust at runtime via `dart:io SecurityContext` (`withTrustedRoots: false` + `setTrustedCertificatesBytes`) — scoped to that one HttpClient instance.
  - Server shells out to `adb exec-out screencap -p`.
  - SAN covers both `10.0.2.2` (emulator → host) and `127.0.0.1` (host health check). No cleartext traffic, no Android manifest changes, no `res/raw` resource, nothing in release builds.
- Screenshots uploaded as artifacts per matrix entry.

### Preview video
- Recorded **natively** — not by stitching frames.
- Both preview scripts (`tool/run_ios_preview.sh`, `tool/run_android_preview.sh`) start `flutter drive` in the background, then wait for the driver to log `Connected to Flutter application` before starting the recorder — so the recording isn't padded with build/install/launch time.
- **iOS:** `timeout -s INT 40s xcrun simctl io "$UDID" recordVideo --codec=h264`. `timeout -s INT` is the documented clean-shutdown signal for `simctl recordVideo`; it finalizes the MP4 `moov` atom and produces a playable file. (The earlier `kill -INT $REC_PID` pattern produced files that froze on the first frame in VLC because the writer was killed mid-flush.)
- **Android:** `adb shell screenrecord --time-limit=40 /sdcard/preview.mp4` then `adb pull`. The clean `--time-limit` exit flushes the MP4 muxer; the previous `pkill -SIGINT screenrecord` pattern hit a long-standing Android bug where SIGINT didn't always finalize the file.
- `integration_test/preview_test.dart` is pure navigation; timing via `linger()` from `test_helpers.dart`.

Both screenshot and preview artifacts must be downloaded and uploaded to App Store Connect / Play Console manually until the metadata lanes (see Release Automation) ship.

## Release Automation (fastlane)

Binary lanes are **implemented** — both `ios beta` and `android beta` ship binaries to TestFlight / Play internal on manual `workflow_dispatch`. The Android job additionally publishes a signed APK as a GitHub Release tagged `build-<github.run_number>` (unique per run; pubspec version shown in the release title + APK filename as flavor, but identity is the run number). Metadata + screenshot upload is **not yet wired**; store listings and screenshots are still uploaded by hand.

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
  release.yml                  # manual trigger (workflow_dispatch)
```

### Lanes
- `ios beta` *(implemented)* — `flutter build ipa` (in workflow), then `upload_to_testflight` with the App Store Connect API key. `skip_waiting_for_build_processing: true` so CI doesn't block on Apple's processing queue.
- `android beta` *(implemented)* — `flutter build appbundle --build-number=$GITHUB_RUN_NUMBER`, then `upload_to_play_store(track: 'internal', release_status: 'draft')`. All metadata/image uploads are explicitly skipped.
- `ios metadata` *(not yet)* — would upload App Store listing + screenshots via `deliver`.
- `android metadata` *(not yet)* — would upload Play listing + screenshots via `upload_to_play_store(skip_upload_aab: true, ...)`.

### Phase rollout
1. ⏳ Android → Play internal track — scaffolding (workflow, Fastfile, `build.gradle.kts`) was in place before any real Play Console app existed, so early `workflow_dispatch` runs all failed at `signReleaseBundle` ("Failed to read key from store: Tag number over 30 is not supported") against empty/placeholder secrets. Actual setup started 2026-04-18: Play Console app being created, Temurin JDK 25 installed locally so `keytool` exists, keystore to live at `C:\Users\Martial\.android\pensine-release.jks`.
2. ✅ iOS → TestFlight (adds cert/profile complexity; ~24h first-build review).
3. ✅ iOS CI signing secrets configured (2026-04-18).
4. ✅ iOS release workflow unblocked (2026-04-18) — p12 re-exported with `-legacy` using the **mingw64** openssl (not msys2's `usr/bin` one) so it pairs with `mingw64/lib/ossl-modules/legacy.dll`. See bootstrap steps below.
5. ✅ Manual signing configured for archive step (2026-04-18) — `flutter build ipa` was failing with "No valid code signing certificates" because the Xcode project defaults to automatic signing with `iPhone Developer`. The workflow now appends `CODE_SIGN_STYLE = Manual` + `CODE_SIGN_IDENTITY = Apple Distribution` (plus the scoped `[sdk=iphoneos*]` variant to override the project.pbxproj override) + `DEVELOPMENT_TEAM` + `PROVISIONING_PROFILE_SPECIFIER` to `ios/Flutter/Release.xcconfig` before the archive step. Values come from secrets, nothing signing-related is baked into the repo.
6. ✅ First TestFlight build uploaded (2026-04-18, build #7). Fixes required along the way: added `NSPhotoLibraryUsageDescription` to Info.plist (ITMS-90683 — `share_plus` links photo library symbols even when unused); bumped runners to `macos-15` and pinned Xcode 26 via `maxim-lobanov/setup-xcode@v1` to meet the iOS 26 SDK deadline (2026-04-28); filled out App Privacy nutrition label ("No data collected"); declared `ITSAppUsesNonExemptEncryption = false`.
7. ⏳ Metadata + screenshot upload (`deliver` + `supply`) once both binary lanes have shipped a real build.

### iOS certificate bootstrap (one-time, Windows)
Certificates are normally generated on a Mac via Keychain Access. From Windows, use OpenSSL:

Use Git for Windows' **mingw64** openssl (not the msys2 one in `usr/bin` — only the mingw64 build ships `legacy.dll`). In CMD:

```cmd
set PATH=C:\Program Files\Git\mingw64\bin;%PATH%
set OPENSSL_MODULES=C:\Program Files\Git\mingw64\lib\ossl-modules

openssl genrsa -out ios_dist.key 2048
openssl req -new -key ios_dist.key -out ios_dist.csr -subj "/emailAddress=YOUR_EMAIL/CN=YOUR_NAME/C=US"
```

Upload `ios_dist.csr` to [developer.apple.com](https://developer.apple.com) → Certificates → **App Store Connect** (under Distribution). Download the `.cer`, then in CMD:

```cmd
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -legacy -inkey ios_dist.key -in distribution.pem -out ios_dist.p12
```

Set an export password when prompted — this becomes `IOS_DIST_CERT_PASSWORD`.

The `-legacy` flag is required: OpenSSL 3.x defaults to HMAC-SHA256 for the PKCS12 MAC, which macOS `security import` rejects with "MAC verification failed". `-legacy` forces the older SHA1-based algorithms that `security` can parse. `OPENSSL_MODULES` must point at the mingw64 provider dir or openssl will fail to load the legacy provider.

Base64-encode with **PowerShell** (not certutil — certutil adds headers and Windows line endings that break `base64 -d` on Linux):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\Martial\.ios\ios_dist.p12"))
```

Files to keep: `ios_dist.key`, `distribution.pem`, `ios_dist.p12` (all in `C:\Users\Martial\.ios\`). Delete `ios_dist.csr` and `distribution.cer`.

Provisioning profile: create in Apple Developer portal → Profiles → **App Store Connect** (Distribution), tied to bundle ID `com.frenchcommando.pensine` + the distribution cert. Name it (e.g. `pensineaction`). Download, base64-encode with PowerShell, add as `IOS_PROVISIONING_PROFILE_BASE64`. Profile name string goes in `IOS_PROVISIONING_PROFILE_NAME`.

App Store Connect API key: App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys. Create with "App Manager" role. Record Key ID → `APPSTORE_CONNECT_API_KEY_ID`, Issuer ID → `APPSTORE_CONNECT_API_ISSUER_ID`. Download `.p8`, base64-encode with PowerShell → `APPSTORE_CONNECT_API_KEY_P8_BASE64`. Store `.p8` in `C:\Users\Martial\.ios\key.p8`.

### Android keystore bootstrap (one-time, Windows)

**Prereq — JDK 25.** `keytool` ships with the JDK, not with Git, Flutter, or Android. Install **Temurin 25** (Eclipse Adoptium, free OpenJDK build) from [adoptium.net](https://adoptium.net/) — tick "add to PATH" + "set JAVA_HOME" in the MSI installer. Matches CI's `actions/setup-java@v4` `distribution: temurin` + `java-version: 25`, so local and CI behave identically. Restart the shell after install so `PATH` picks up `keytool`.

Files live under `C:\Users\Martial\.android\` (mirrors the `.ios` convention). In CMD:

```cmd
cd C:\Users\Martial\.android
keytool -genkey -v -keystore pensine-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pensine
```

`keytool` prompts for store password, key password (use the same — Gradle's signing config supplies them separately but they can match), and a DN. Remember the values for `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD`.

Base64-encode with **PowerShell** (same reason as iOS — certutil adds headers/CRLF that break `base64 -d` on Linux; Git-Bash `base64 -w 0` works too but PowerShell keeps Windows and Linux behaviors aligned):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\Martial\.android\pensine-release.jks"))
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
- Flutter's default iOS project uses automatic signing with `iPhone Developer` identity — fine locally, fatal on CI runners that have no Apple ID logged in. The release workflow overrides this via xcconfig append (see phase rollout step 5). If you ever regenerate the iOS project, re-verify the override still bites.
- PKCS12 re-export on Windows: use the **mingw64** openssl (`C:\Program Files\Git\mingw64\bin\openssl.exe`) with `-legacy` and `OPENSSL_MODULES=C:\Program Files\Git\mingw64\lib\ossl-modules`. The msys2 openssl at `C:\Program Files\Git\usr\bin\openssl.exe` doesn't ship a legacy provider and will fail even with `OPENSSL_MODULES` pointed at the mingw dir.
- `keytool` is a JDK tool, not an Android one — Flutter's Android toolchain doesn't pull it in. Install Temurin 25 locally so `keytool` is on PATH; match the `temurin` / `25` combo used by `actions/setup-java@v4` in `release.yml`.
- Play Console internal testing track requires at least one tester email before the track accepts a release. Add yourself (`martialren@gmail.com`) as a one-person "Me" tester list — satisfies the validation and lets you install the build. Not to be confused with the 12-tester / 14-day requirement, which is closed-testing-to-production only.
- Google Play closed-testing requirement for personal accounts created after Nov 2023: 12+ testers running for 14+ days before first production release. Internal track is unaffected. Does not apply to organization accounts.

## Shared requirements (all stores)
- Privacy policy page — host on GitHub Pages (e.g. `frenchcommando.github.io/pensine/privacy`)
- Version bump in `pubspec.yaml` before each release
