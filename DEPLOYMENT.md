# App Store Deployment

## Current state
- App ID: `com.frenchcommando.pensine` (both platforms)
- App icons: configured for all sizes via `flutter_launcher_icons`
- Version: defined in `pubspec.yaml`, currently `1.1.3` (no `+<build>` suffix — build number injected at CI build time from `github.run_number`)
- iOS deployment target: 13.0
- Android: uses Flutter default min/target SDK versions
- Android release signing: `build.gradle.kts` reads from `android/key.properties` (written by CI from secrets); keystore + secrets configured, first release shipped to Play internal
- iOS development team: injected via `APPLE_TEAM_ID` secret at CI build time (not baked into the Xcode project)
- Screenshots + preview video: **automated** (see Screenshots & Preview Video)
- Binary upload: **automated** (both platforms — see Release Automation); metadata + screenshot upload: **not automated yet**

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
- ✅ Live URL: `https://apps.apple.com/app/pensine/id6762313502` (Apple ID: `6762313502`)
- ✅ Release setting: **Automatically release this version** (after Apple approval) — each new version still needs a manual "Add for Review" click in App Store Connect, but no second click is required once it clears review.
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
- ✅ TestFlight External Testing: group created (2026-04-19), Beta App Review passed, public link live at `https://testflight.apple.com/join/KDHvbWKH` (linked from README + landing page, mirrors the Android Google Group flow)

**No local Mac — fully CI-based:**
- GitHub Actions macOS runners (free for public repos)
- `ci.yml`'s `build-ios` job — builds iOS (no signing) on push/PR to main, proves the app compiles
- Release signing + TestFlight upload: see Release Automation below
- Not using `fastlane match` (solo-dev, CI-only signing → GitHub Secrets directly is simpler)

## macOS (Mac App Store + Developer ID DMG)

**Two parallel channels, both automated:**
- **Mac App Store** — `macos-mas-release` job builds, signs, wraps in `.pkg`, uploads to App Store Connect. Release setting is **Automatically release this version**, same pattern as iOS (you still click **Add for Review** per version in App Store Connect; auto-release fires on approval).
- **Developer ID DMG** — `macos-dmg-release` job builds, Developer-ID-signs, notarizes with `xcrun notarytool`, staples, wraps in a notarized `.dmg` via `create-dmg`, attaches it to the same GitHub Release tag as the APK/zip/installer.

**Testing story:** Primary path is CI — `integration.yml`'s `macos` job runs `smoke_test.dart` + `pending_import_test.dart` on `macos-15` for every PR, which is the guaranteed signal since you don't have a Mac. The OSX-KVM VM under `local/IOS/` is also a candidate for local `flutter drive -d macos` runs (QEMU is already set up there for iOS work; `flutter drive` talks to the Dart VM Service over a port, so VNC isn't in the hot path) — viability hasn't been measured yet. `tool/run_macos_integration.sh` gates on `CI=true`; override locally if you want to try the VM and accept the data-pollution risk.

**App Store Connect listing:**
- Add macOS to the existing app record `id6762313502` (App Store Connect → Pensine → **+ macOS**). Keeps the unified "Works on iPhone, iPad, Mac" listing. Bundle ID stays `com.frenchcommando.pensine`; SKU is `pensine-macos` (distinct from iOS's `pensine`).
- Category: `public.app-category.productivity` (baked into `macos/Runner/Info.plist`).
- Min macOS: 11.0 Big Sur (Flutter default, ~95% of active Macs).
- Release setting: **Automatically release this version** (match iOS).
- Screenshots: separate set required for Mac (1280×800 up to 2880×1800). No automation for macOS screenshots yet — capture manually on first submission.

**Certificates (three required — generate CSR with openssl on Windows, same pattern as the iOS `ios_dist.csr` flow already documented below):**

| Cert type | For | GitHub Secret |
|---|---|---|
| **3rd Party Mac Developer Application** | Code-signs `.app` inside `.pkg` for MAS | `MAC_MAS_CERT_BASE64` + `MAC_MAS_CERT_PASSWORD` |
| **3rd Party Mac Developer Installer** | Product-signs the `.pkg` for MAS | `MAC_INSTALLER_CERT_BASE64` + `MAC_INSTALLER_CERT_PASSWORD` |
| **Developer ID Application** | Signs the `.app` for outside-store DMG distribution | `MAC_DEV_ID_CERT_BASE64` + `MAC_DEV_ID_CERT_PASSWORD` |

Plus one provisioning profile:

| Profile | GitHub Secret |
|---|---|
| **Mac App Store Distribution** (tied to `com.frenchcommando.pensine` + the MAS Application cert) | `MAC_MAS_PROFILE_BASE64` + `MAC_MAS_PROFILE_NAME` |

**Reused from iOS pipeline (no new values to add):** `APPSTORE_CONNECT_API_KEY_ID`, `APPSTORE_CONNECT_API_ISSUER_ID`, `APPSTORE_CONNECT_API_KEY_P8_BASE64`, `APPLE_TEAM_ID`. The team-wide API key authenticates both iOS TestFlight uploads, macOS App Store uploads, and `xcrun notarytool` submissions.

**Entitlements** (`macos/Runner/Release.entitlements`): `app-sandbox` (MAS requires; kept on for DMG too for consistency) + `files.user-selected.read-write` (file picker) + `network.client` (`url_launcher` outbound). Debug adds `cs.allow-jit` + `network.server` for the Flutter debug bridge.

**`.pensine` file association** is declared in `macos/Runner/Info.plist` (`CFBundleDocumentTypes` + `UTExportedTypeDeclarations`, same UTI `com.frenchcommando.pensine.workspace` as iOS). `AppDelegate.swift::application(_:open:)` writes the bytes to `NSTemporaryDirectory()/pensine_incoming.pensine` — `pending_import_native.dart` polls that file on cold launch and on resume, matching the iOS SceneDelegate pattern.

**DMG not notarizing?** Most likely causes in order: (1) hardened runtime not enabled — check `ENABLE_HARDENED_RUNTIME = YES` in `macos/Runner/Configs/Release.xcconfig` at build time (the job's `cat >>` appends it); (2) Developer ID cert not installed with the right `productbuild`/`codesign` partition list — keychain import in the job uses the same `-T /usr/bin/codesign` pattern as iOS; (3) notarytool auth — check the API key is the same one that works for iOS TestFlight.

**Reading Apple's rejection reason** — `xcrun notarytool submit --wait` returns exit 0 even when Apple rejects the submission, it just reports `status: Invalid` in stdout. The CI step runs `--output-format json`, parses the result with `jq`, and on anything other than `Accepted` runs `xcrun notarytool log <submission-id>` to fetch Apple's structured rejection reason (specific file paths, entitlement violations, timestamping errors). Without that log-fetch step every failure looks identical — "status: Invalid, stapler Error 65" — and iteration is blind.

**`notarytool submit --wait` has no internal wall-clock limit.** Apple's notary can hang indefinitely on their end; `--wait` polls until they respond. Always pass `--timeout 20m` so the step fails fast and the log-fetch block below gets to run. Without it, a stuck Apple-side submission eats the whole 45-min job budget and the step dies on the job timeout before capturing any diagnostic output. Wrap the submit in `set +e` / capture `$?` / `set -e` so a non-zero exit (from timeout or hard failure) doesn't abort the script under bash's `-e` mode — the log fetch needs to run regardless of how the submit ended.

**Mac TestFlight:** skipped initially. Available on the same `upload_to_testflight` fastlane action if we want it later — would need a fourth cert (Mac App Distribution without "3rd Party" prefix) and a separate profile. Direct App Store submission with auto-release matches the iOS cadence you already run.

## Windows — Inno Setup installer + sideload zip (primary channels)

Windows ships two artifacts on every GitHub Release alongside the APK:

- **Installer** — `pensine-v<version>-build<N>-setup.exe`. Per-user install (no admin), Start Menu entry, `.pensine` file association, proper uninstaller. Recommended path for most users.
- **Portable zip** — `pensine-v<version>-build<N>-windows.zip`. Extract anywhere, run `pensine.exe`. No file association, no uninstaller. Use case: USB-stick installs, locked-down corporate PCs that block installers but allow zip extraction, or anyone who wants to leave no trace on the host machine.

**Requirements:** Windows 10 version 1809 (build 17763) or later, on an x64 PC or an ARM64 Windows 11 PC. Enforced by the installer via `MinVersion=10.0.17763` + `ArchitecturesAllowed=x64compatible` in `pensine.iss` — wrong-OS / wrong-CPU users see a single "you need …" dialog instead of the cryptic Inno Setup default.

Users:

1. Open `github.com/FrenchCommando/pensine/releases/latest` on their PC.
2. Download the installer (or the zip).
3. Run the installer (or extract the zip and run `pensine.exe`).
4. Accept the SmartScreen "Run anyway" warning (expected — no code-signing cert; installer prompts once at install, zip prompts every fresh extract).

Both artifacts come from the `windows-release` job in `release.yml` running on `windows-latest`:
- `flutter build windows --release` → `build\windows\x64\runner\Release\*`
- `Compress-Archive` → the zip
- `ISCC.exe windows\installer\pensine.iss` → the installer (`build\windows\installer\pensine-v<version>-build<N>-setup.exe`)

Both attached to the release tagged `build-<run_number>` via `softprops/action-gh-release@v2` (create-or-update on tag — appends to the release the android-release job creates).

`ci.yml`'s `build-windows` job additionally uploads both as workflow artifacts on every push/PR, so any green build is downloadable for QA without cutting a formal release.

**File association** comes from registry entries in the Inno Setup script (`windows/installer/pensine.iss`): `.pensine` → `Pensine.Workspace` ProgId → `pensine.exe "%1"`. The C++ runner (`windows/runner/utils.cpp::HandleIncomingPensineFile`) reads `argv` for the first `.pensine` path, copies its bytes to `%TEMP%\pensine_incoming.pensine`, and the existing Dart polling pipeline (`pending_import_native.dart`) picks it up on cold launch — same handoff pattern as iOS/Android.

**Uninstall** is handled by the Inno-generated `unins000.exe` plus the standard Settings → Apps → Pensine entry. Every `[Registry]` line uses `uninsdeletevalue` / `uninsdeletekey` flags so the file association cleans up. User data under `%APPDATA%\pensine\` is intentionally preserved across uninstall/reinstall — `path_provider` writes there, outside `{app}`, so the uninstaller never touches it. The portable zip has no uninstaller — `delete the folder` is the uninstall path.

## Linux — AppImage + .deb (GitHub Release only)

Linux ships two unsigned artifacts on every GitHub Release alongside the APK / .dmg / Windows assets:

- **AppImage** — `pensine-v<version>-build<N>-linux-x86_64.AppImage`. Single self-contained file. Chmod +x, double-click (or run from a terminal). Works on any reasonably modern glibc-based distro (Ubuntu 20.04+, Fedora, Arch, Debian stable, etc.). No install step, no system integration, no uninstaller — delete the file to remove.
- **.deb** — `pensine-v<version>-build<N>-linux-amd64.deb`. Debian/Ubuntu native install: `sudo apt install ./pensine-...deb`. Installs to `/usr/lib/pensine/`, drops a shim at `/usr/bin/pensine`, registers the `.desktop` entry (app launcher menu), the icon, and the `.pensine` MIME type (`application/x-pensine`). Uninstall via `sudo apt remove pensine`. Not signed, no GPG key — apt will warn once about "untrusted origin," same as every sideloaded .deb.

Both come from the `linux-release` job in `release.yml` running on `ubuntu-latest`:
- Install build deps (`clang cmake ninja-build pkg-config libgtk-3-dev libfuse2`)
- `flutter build linux --release` → `build/linux/x64/release/bundle/*`
- `linux/packaging/build_deb.sh` stages the install tree, writes `DEBIAN/control` with declared deps (`libgtk-3-0`, `libglib2.0-0`, `libstdc++6`, `libc6`), runs `dpkg-deb --build` → the .deb
- `linux/packaging/build_appimage.sh` stages an `AppDir`, downloads `linuxdeploy` + `linuxdeploy-plugin-gtk` into a tmp dir (nothing checked in), `--appimage-extract`s linuxdeploy to sidestep the GHA runner's FUSE policy, runs it against the AppDir → the AppImage
- Both uploaded via `softprops/action-gh-release@v2` to the same `build-<run_number>` tag as every other platform.

**File association** is declared in `linux/packaging/pensine-mime.xml` (`application/x-pensine` for `*.pensine`) and referenced from `linux/packaging/pensine.desktop` (`MimeType=application/x-pensine;`). The .deb's `postinst` / `postrm` run `update-mime-database` + `update-desktop-database` + `gtk-update-icon-cache` so the association is live immediately, no re-login. AppImage carries the same `.desktop` + MIME files inside; desktop integration kicks in if the user has `appimaged` installed (optional; the binary runs fine without it — just no menu entry). The C++ runner picks up a `.pensine` path from `argv[1]` the same way the Windows runner does; the existing `pending_import_native.dart` polling pipeline handles the handoff to Dart.

**Requirements (.deb):** Ubuntu 20.04+ / Debian 11+ or equivalent. GTK 3 is the only non-trivial dep and it's preinstalled on every desktop distro. **Requirements (AppImage):** glibc 2.31+ (same floor; AppImage bundles everything else).

**Not pursued:** Flathub, Snap Store, distro-native repos (PPA, AUR, Fedora Copr). The AppImage+.deb combo covers ~95% of Linux desktop users with zero store-review latency and zero ongoing maintenance. Revisit if (a) we want the "auto-update from the store" experience, (b) a specific distro user base complains, or (c) the Flathub review value becomes worth it for discoverability.

## Microsoft Store (Windows)

**Status: deferred indefinitely, not actively pursued.** The Inno Setup installer channel now fills the same user-facing role the Store would (proper install/uninstall, `.pensine` file association) without depending on a Store account, so the Store path is nice-to-have, not a gap.

Background: Partner Center individual-developer registration (free, ID-verified) has been unreliable in practice — signup flow errors with no clear remediation. Don't interpret the dormant MSIX pipeline as "one step away from shipping" — it's been tried. Only revisit if Microsoft fixes the signup flow or we decide the Store listing itself adds enough marketing value to push through the friction.

If the account ever does come through, the plumbing is already in place: the MSIX pipeline in `ci.yml` + `pubspec.yaml` gates on the `MSIX_PUBLISHER` secret, so MSIX build + WACK validation are skipped automatically until that lands. Setting the 4 `MSIX_*` secrets re-enables the full flow with zero code change.

**Account:** Microsoft Partner Center — **free** for individual developers at `partner.microsoft.com/dashboard` (new onboarding flow, ~200 markets). Identity is verified via government-issued ID + selfie (MFA enforced); verified data auto-fills the developer profile, then redirects to Partner Center. Account is tied to a Microsoft account (personal MSA or work/school Azure AD) — ownership is hard to transfer, so pick deliberately. (Historical: the $19 one-time fee was waived for individuals in the new flow; organization accounts still pay.)

**App reservation (one-time):**
1. Partner Center → Apps and games → **New product** → **MSIX or PWA app**.
2. Reserve the app name "Pensine" (fall back to e.g. "Pensine Notes" if taken).
3. From the app identity page, grab the four values that feed GitHub Secrets + the CI lane:
   - **Publisher Display Name** → `MSIX_PUBLISHER_DISPLAY_NAME`
   - **Publisher ID** (the `CN=...` string, under Account settings → Identity) → `MSIX_PUBLISHER`
   - **Package Identity Name** (e.g. `12345FrenchCommando.Pensine`) → `MSIX_IDENTITY_NAME`
   - **Store ID** (12-char alphanumeric) → `MSIX_STORE_ID` (for future Partner Center Submission API automation)

**Build format:** MSIX (`dart run msix:create --store`). Microsoft re-signs the package during Store upload — the generated MSIX is unsigned and not directly sideloadable.

**CI workflow** (`ci.yml`'s `build-windows` + `validate-msix` jobs — push/PR triggers, not `release.yml`):
- Runs on `windows-latest` (Windows SDK, MakeAppx, SignTool preinstalled).
- `build` job: `flutter build windows --release` on every push/PR (proves compilation). On push-to-main only (where secrets are available), additionally runs `dart run msix:create --store` with identity flags injected from Secrets.
- `validate` job (push-to-main only, `needs: build`): downloads the MSIX artifact, runs WACK (`appcert.exe`) against it, uploads `wack-report.xml`. ~10-15 min.
- Produces `pensine-v<version>-build<N>.msix` as a workflow artifact — download from the Actions UI and upload manually to Partner Center until API automation lands.
- Split rationale: `release.yml` is reserved for actual distribution actions (Play Store upload, TestFlight upload). Build + certification happens on every commit to main, not gated behind a manual trigger.

**Version rules (MSIX):**
- 4-part `a.b.c.d`; Store requires the 4th part to be `0`.
- Version string is `<pubspec version>.0`, e.g. pubspec `1.1.3` → MSIX `1.1.3.0`.
- Store rejects duplicate versions across submissions, so **every Store upload requires a pubspec version bump** (unlike Play internal / TestFlight, which accept same version name with different build numbers).
- In-app build number (About dialog) still comes from `github.run_number` via `flutter build windows --build-number=...`.

**Manual store-listing tasks (one-time):**
- App name, description, category
- Content rating (IARC) questionnaire
- Privacy policy URL (same `https://frenchcommando.github.io/pensine/privacy.html` used for Play/App Store)
- Age rating, price (Free), accessibility notes
- Screenshots — Partner Center requires at least one 1366x768 or larger; reuse the web/mobile screenshots from `artifacts.yml` or capture Windows-native ones
- First submission must go through manual review (~hours to a few days)

**Phase rollout:**
1. ✅ `msix` dev dep + `msix_config` in `pubspec.yaml` (non-identity fields only)
2. ✅ `ci.yml`'s `build-windows` job producing MSIX artifact on push to main
3. ✅ `ci.yml`'s `validate-msix` job running Windows App Certification Kit (WACK / `appcert.exe`) against the MSIX artifact — report uploaded as `wack-report-build-<N>`
4. ⏳ Partner Center account + app reservation (manual — individual registration is free; ID-verification flow)
5. ⏳ GitHub Secrets populated (`MSIX_PUBLISHER_DISPLAY_NAME`, `MSIX_IDENTITY_NAME`, `MSIX_PUBLISHER`, `MSIX_STORE_ID`)
6. ⏳ First manual upload to Partner Center (download MSIX artifact from the Actions run)
7. ⏳ Partner Center Submission API automation — new `windows-store-release` job in `release.yml` that downloads the most recent MSIX artifact from `ci.yml` and uploads via Azure AD app registration + `msstore-cli` or direct API calls
8. ✅ `.pensine` file association on Windows — shipped via the Inno Setup installer channel; MSIX would also pick it up via manifest `FileTypeAssociation` if/when the Store path lands.

**Required GitHub Secrets (Windows):**
- `MSIX_PUBLISHER_DISPLAY_NAME` — human-readable publisher name (e.g. "Martial Ren")
- `MSIX_IDENTITY_NAME` — Package Identity Name from Partner Center
- `MSIX_PUBLISHER` — the `CN=...` Publisher ID string, verbatim
- `MSIX_STORE_ID` — 12-char Store ID (not used yet; reserved for upload automation)

## Screenshots & Preview Video

Automated via `.github/workflows/artifacts.yml` (manual trigger). All multi-step orchestration lives in shell scripts under `tool/` because the `reactivecircus/android-emulator-runner` action runs each YAML `script:` line as a separate `sh -c`, fragmenting variables.

Test helpers (`settle`, `linger`, `scrollTo`) are shared between screenshot and preview tests in `integration_test/test_helpers.dart`.

### Screenshots
- Test: `integration_test/screenshot_test.dart`. Driver: `test_driver/integration_test.dart` (uses `integration_test_driver_extended` with `onScreenshot`).
- Status-bar polish (9:41 clock, full battery, full signal) applied via `tool/setup_ios_status_bar.sh` / `tool/setup_android_status_bar.sh`.
- Both platforms use **host-driven capture** via `tool/screenshot_server.py`. The test POSTs `/screenshot/<name>` to the server; the server shells out to the platform's native capture and writes `build/screenshots/<name>.png` synchronously, so a 200 response is the test's signal to advance. The test flips `debugPauseMarblePhysics` around each capture so marbles don't drift mid-frame — the flag also stops the Ticker, so `hasScheduledFrame` goes false cleanly during the capture window. Historical note: this host-driven path originally existed because `binding.takeScreenshot` / `convertFlutterSurfaceToImage` hung waiting for idle that never came (the physics ticker re-scheduled every frame). That's fixed now via ticker idle detection + `debugPauseMarblePhysics` stopping the ticker — `binding.takeScreenshot` would likely work — but the host-driven pipeline is already in place and reliable, so it stays.
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
1. ✅ Android → Play internal track. Historical note: early `workflow_dispatch` runs failed at `signReleaseBundle` ("Failed to read key from store: Tag number over 30 is not supported") against placeholder secrets. Resolved 2026-04-18 once the keystore at `C:\Users\Martial\.android\pensine-release.jks` and all four Android secrets landed.
2. ✅ iOS → TestFlight (adds cert/profile complexity; ~24h first-build review).
3. ✅ iOS CI signing secrets configured (2026-04-18).
4. ✅ iOS release workflow unblocked (2026-04-18) — p12 re-exported with `-legacy` using the **mingw64** openssl (not msys2's `usr/bin` one) so it pairs with `mingw64/lib/ossl-modules/legacy.dll`. See bootstrap steps below.
5. ✅ Manual signing configured for archive step (2026-04-18) — `flutter build ipa` was failing with "No valid code signing certificates" because the Xcode project defaults to automatic signing with `iPhone Developer`. The workflow now appends `CODE_SIGN_STYLE = Manual` + `CODE_SIGN_IDENTITY = Apple Distribution` (plus the scoped `[sdk=iphoneos*]` variant to override the project.pbxproj override) + `DEVELOPMENT_TEAM` + `PROVISIONING_PROFILE_SPECIFIER` to `ios/Flutter/Release.xcconfig` before the archive step. Values come from secrets, nothing signing-related is baked into the repo.
6. ✅ First TestFlight build uploaded (2026-04-18, build #7). Fixes required along the way: added `NSPhotoLibraryUsageDescription` to Info.plist (ITMS-90683 — `share_plus` links photo library symbols even when unused); bumped runners to `macos-15` and pinned Xcode 26 via `maxim-lobanov/setup-xcode@v1` to meet the iOS 26 SDK deadline (2026-04-28); filled out App Privacy nutrition label ("No data collected"); declared `ITSAppUsesNonExemptEncryption = false`.
7. ✅ Document configuration declared (2026-04-19) — added `LSSupportsOpeningDocumentsInPlace = NO` to Info.plist (ITMS-90737 — any app that declares `CFBundleDocumentTypes` must also declare in-place support; NO matches Pensine's behavior of copying imports into local storage). Plist correctness is enforced by App Store Connect's validator at upload time, not by `flutter build ipa` — first warning comes from the rejection email.
8. ⏳ Metadata + screenshot upload (`deliver` + `supply`) once both binary lanes have shipped a real build.

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
- **iOS `CFBundleVersion`**: derived from `github.run_number` at build time, passed via `--build-number` to `flutter build ipa`. Same mechanism as Android.
- **Android `versionCode`**: derived from `github.run_number` at build time, passed via `--build-number` to `flutter build appbundle`. Monotonic across all runs.
- **Short version string** (e.g. `1.1.3`) stays in `pubspec.yaml`; the build number is injected at CI build time, never in pubspec.

### Gotchas (one-time or recurring)
- Apple Developer enrollment can take hours to days for org accounts; usually same-day for individuals.
- TestFlight Beta App Review (External Testing) is ~24h for the first build, minutes for subsequent. Internal Testing skips review entirely.
- Distribution cert + provisioning profile expire yearly — `fastlane cert`/`sigh` renew in ~5 min.
- Privacy manifest (`ios/Runner/PrivacyInfo.xcprivacy`) required for new App Store submissions (post-May 2024). Flutter 3.19+ ships a default; verify or customize.
- Flutter's default iOS project uses automatic signing with `iPhone Developer` identity — fine locally, fatal on CI runners that have no Apple ID logged in. The release workflow overrides this via xcconfig append (see phase rollout step 5). If you ever regenerate the iOS project, re-verify the override still bites.
- PKCS12 re-export on Windows: use the **mingw64** openssl (`C:\Program Files\Git\mingw64\bin\openssl.exe`) with `-legacy` and `OPENSSL_MODULES=C:\Program Files\Git\mingw64\lib\ossl-modules`. The msys2 openssl at `C:\Program Files\Git\usr\bin\openssl.exe` doesn't ship a legacy provider and will fail even with `OPENSSL_MODULES` pointed at the mingw dir.
- `keytool` is a JDK tool, not an Android one — Flutter's Android toolchain doesn't pull it in. Install Temurin 25 locally so `keytool` is on PATH; match the `temurin` / `25` combo used by `actions/setup-java@v4` in `release.yml`.
- Play Console internal testing track requires at least one tester email before the track accepts a release. Add yourself (`martialren@gmail.com`) as a one-person "Me" tester list — satisfies the validation and lets you install the build. Not to be confused with the 12-tester / 14-day requirement, which is closed-testing-to-production only.
- Google Play closed-testing requirement for personal accounts created after Nov 2023: 12+ testers running for 14+ days before first production release. Internal track is unaffected. Does not apply to organization accounts. `local/copy_tester_email.bat` (runs `local/copy_tester_email.ps1`) puts the recruitment email on the Windows clipboard as rich HTML + plain-text fallback — paste into Gmail compose, send. Links go to the `pensine-testers` Google Group → Play Console tester-opt-in URL → Play Store listing, in that order (all three must use the same Google account for Play to match the tester).

## Shared requirements (all stores)
- Privacy policy page — host on GitHub Pages (e.g. `frenchcommando.github.io/pensine/privacy`)
- Version bump in `pubspec.yaml` before each release
