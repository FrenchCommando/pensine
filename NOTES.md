# Notes

## Windows Setup
- Flutter requires Developer Mode enabled (`ms-settings:developers`) for symlink support when building with plugins.

## Known Issues
- `Failed to update ui::AXTree` errors on Windows — known Flutter bug with accessibility bridge during rapid widget updates (60fps ticker). Harmless, ignore.
- **Marble physics ticker idles when the board is at rest.** `MarbleBoardState._tick` stops the Ticker when `_isIdle()` holds (no drag, no dying marbles, all velocities zero, all scale/expandScale lerps within 0.005 of target). Deadband at the end of the physics loop snaps sub-1px/s velocities to zero so exponential friction doesn't asymptote forever. Interaction paths (`shake`, `resetSizes`, pan/tap/double-tap handlers, `_syncMarbles`) call `_ensureTickerRunning()` to restart it. Most common idle state: all items done on a net-having board — marbles converge to the net, velocities deadband to zero, ticker stops, `hasScheduledFrame` goes false, `pumpAndSettle` unblocks. Setting `debugPauseMarblePhysics = true` also stops the ticker on its next tick — screenshot tests rely on this. The `settle()` helper in `integration_test/test_helpers.dart` still exists because it's also a bounded-wait primitive: tests use it to let a live marble board animate for a few seconds without blocking on full idle (which would take ~60s for friction to decay initial velocities). Prefer `pumpAndSettle` when the scene has no active marble board (home screen, post-Back navigation); use `settle()` on a live board.
- **No low-speed wander nudge.** The old `if speed < 30: nudge` block in `_tick` was legacy from a vertical-gravity era and re-energized marbles every frame, preventing rest. Removed in favour of the idle detection above.

## Color API convention
- Use `.withValues(alpha: <0.0–1.0>)` across all Flutter `Color` / `Colors` call sites. `.withAlpha(int)` and `.withOpacity(double)` are legacy — `.withValues()` is the wide-gamut-aware API Flutter is standardising on.

## Web Deployment
- GitHub Pages: `https://frenchcommando.github.io/pensine/` (the app)
- Landing page: `https://frenchcommando.github.io/pensine/site/` (static, in `web/site/`)
- Privacy policy: `https://frenchcommando.github.io/pensine/privacy.html` (static, in `web/`)
- Deployed via `.github/workflows/deploy.yml` on every push to `main`
- Requires GitHub repo Settings → Pages → Source set to **GitHub Actions**
- Base href is set dynamically in `web/index.html` — works on both GitHub Pages and local serving
- Local: `flutter build web && npx serve build/web`

## Storage
- One file/key per board (UUID as identifier), not a single blob
- Desktop: `boards/{id}.pensine` files in app support directory via `path_provider`
- Web/Mobile: one `shared_preferences` key per board + index key for board IDs
- Legacy single-file format (`pensine_data.json` / `pensine_boards` key) auto-migrates on first load
- Saves are per-board (only the changed board is written)
- Board order persisted: web/mobile via the index key, desktop via `boards/_order.json`
- Order updated on reorder, delete, and bulk save
- **Gotcha — shared_preferences index writes race.** `_saveBoardPref` does `getStringList → add → setStringList` on `pensine_board_ids`; parallel calls (e.g. `Future.wait(boards.map(saveBoard))`) can drop ids because the last writer wins. Always end any bulk save with an explicit `saveBoardOrder(ids)` — it overwrites the index authoritatively and hides the race. Same pattern for workspaces. Desktop is file-per-board so it isn't affected.
- **Legacy migration must persist order.** Desktop `_loadDesktop` migrates the legacy blob → per-file `.pensine` writes; without a matching `saveBoardOrderFile`, the next launch gets filesystem-listing order and the user's arrangement is lost. Prefs `_loadPrefs` delegates to `saveAllBoards` for the same reason (and to dodge the race above).

## App Icon
- Custom pensieve (memory basin) icon in `assets/app_icon.svg`
- Converted to PNG via `npx sharp-cli`, then `flutter_launcher_icons` generates all platform sizes
- Regenerate with `tool\generate_icon.bat` (Windows) or `tool/generate_icon.sh` (Unix)
- Config in `pubspec.yaml` under `flutter_launcher_icons:`
- `remove_alpha_ios: true` set for App Store compliance
- PNG is tracked in git (was previously gitignored, but CI needs it)
- `assets/app_icon.png` also registered as a Flutter asset for in-app usage (app bar title, empty state, about dialog)

## Workspaces
- Boards are grouped into workspaces (collections of related boards)
- Every board belongs to exactly one workspace (`Board.workspaceId`)
- Workspace model: `lib/models/workspace.dart` (id, name, colorIndex, createdAt)
- Home screen shows expandable/collapsible workspace sections; collapsed state persisted via `shared_preferences` key `pensine_collapsed_workspaces`
- Workspace operations via popup menu: rename, color, add board, export, delete
- Board popup menu includes "Move to workspace" when multiple workspaces exist
- New board dialog includes workspace picker dropdown when multiple workspaces exist
- Delete workspace deletes all its boards (with confirmation)
- Storage: desktop uses `{id}.workspace` files + `_workspace_order.json`; web/mobile uses `pensine_workspace_{id}` keys + `pensine_workspace_ids` order key
- Migration: existing boards (pre-workspace) are assigned to a new "General" workspace on first load
- Default example workspaces: Welcome, Cooking Recipes, Workout Routines, French Vocab, Pilot Checklists — each with 2-4 boards showcasing different board types (including timer and countdown)
- Default workspaces defined in `home_screen.dart` (`_defaults()`) — shown on first launch and after reset

## Board Interactions
- **Thoughts**: tap to expand/collapse, long-press to edit
- **To-do**: tap to catch in net (done), long-press to edit, reset button releases all
- **Flashcards**: tap to flip, tap again = wrong (flips back, grows), double-tap = correct (shrinks to net), flip-all button, reset button. If the item has a `description`, the flipped card auto-expands and shows `backContent` + `description` together (reuses the same expansion render path as thoughts/sequential — gated on `m.flipped && description != null` in `_isIdle`, the physics tick, and paint).
- **Steps (checklist)**: sequential order — active step inflates and shows description, numbered marbles, tap active step to complete, tap any other marble to jump there (sets everything before it as done), reset button
- **Timer**: like checklist + stopwatch overlay. Timer starts when first step is completed, shows total elapsed and per-step time. Each advance appends a `Lap` (itemId + elapsedSeconds + recordedAt) to `Board.laps`. Bottom-right shows the lap log. Reset clears timer state **and laps** (tap-back to an earlier marble preserves laps — Reset is the clean-slate action). Overlay freezes on the final total when all steps complete (ticker cancelled, start time kept).
- **Countdown**: like checklist + per-step countdown. Each item has `durationSeconds`; auto-advances when countdown hits zero. Marbles still tappable to jump around. Duration field in add/edit dialogs. Auto-advance also appends a `Lap`. Reset clears countdown state + laps; overlay freezes on the final total on completion (same freeze-not-stop behaviour as timer).
- **Start marble convention (timer/countdown)**: item at index 0 arms the clock but is never logged as a lap — for both the manual-tap (timer) and auto-fire (countdown) paths. Treat it as a dedicated "Start" sentinel. Examples `Flight Log` and `Tabata` in `_defaults()` use this (Engine start / Shutdown; Warm-up / Cool-down).
- **All boards**: drag to fling, long-press empty space to add, shake button scatters marbles

## Mobile UX
- **Screen wake lock**: any open board keeps the screen on via `wakelock_plus` (enabled in `BoardScreen.initState`, released in `dispose`). Released on returning to the home screen. No-op on platforms that don't support it.
- **Haptics**: `HapticFeedback` (no extra package, mobile-only by nature) fires on:
  - Sequential step advance (`selectionClick`)
  - Countdown auto-advance (`lightImpact`)
  - All-steps-done celebration (`mediumImpact`)
  - Marble deletion from edit dialog (`lightImpact`)

## UI
- Dark/light theme toggle (persisted via `shared_preferences`), available on all screens
- Board view toggle in app bar: marble physics view (default) ↔ table view (`ItemsTable`) — columns adapt to board type (details, back, duration, done, size). Persisted as `Board.tableMode` (rides along with the board's data, including in `.pensine` exports).
- Table mode: drag handle on each row reorders items (`ReorderableListView`, custom handle via `ReorderableDragStartListener` so long-press stays free for "edit item"). FAB appears for adding items when the board is non-empty; positioned `FloatingActionButtonLocation.startFloat` (bottom-left) so it doesn't cover the timer/lap overlay (bottom-right).
- Board app bar action order: shake / flip-all / reset on the left (conditional, appear/disappear), then the anchored trio marble-table · dark-mode · about on the right. Keeps the right-side layout stable as conditional actions come and go. Reset stays visible on timer/countdown boards even with nothing done, so lingering laps (post reverse-to-zero) can still be cleared.
- About dialog accessible from all screens, includes "Reset data" to restore default example boards
- Default example boards are hardcoded in `home_screen.dart` (`_defaults()`), used on first launch and reset
- Marble/net sizes scale with screen size (responsive, no hardcoded pixel values)
- Marble diameter capped at 80% of shortest screen side
- Expanded thoughts bubble capped to fit screen
- Text in marbles auto-shrinks to fit; single-word labels forced to one line (no mid-word wrap)
- New board dialog: vertical list of board types (not horizontal segmented button — too narrow on phones)
- New board dialog: Enter key submits
- Color picker in add/edit dialogs
- iOS PWA install banner in `web/index.html` (shows once, dismissible)
- All dialogs use `SingleChildScrollView` to avoid overflow on small screens
- Avoid `Spacer()` in `AlertDialog.actions` — causes dialog to expand on large screens
- Boards can be reordered by long-press drag on the home screen
- Boards can be renamed via popup menu (three dots)
- Swipe-to-delete shows undo snackbar instead of deleting immediately
- About dialog shows board type icons next to descriptions
- About dialog shows board/marble count stats (home screen only)
- Boards can be duplicated via popup menu (uses `copyWithNewIds`)
- Board type can be changed after creation via popup menu (data format is universal)
- Delete from popup menu requires confirmation dialog
- Per-board accent color via popup menu — tints app bar title, net, and home screen icon (`Board.colorIndex`, -1 = default)
- Marble exit animation: deleted marbles shrink to zero before removal
- Accessibility: `Semantics` label on marble board, tooltips on all icon buttons
- Quicksand font bundled in `assets/fonts/` (no internet needed on first launch)

## Keyboard (desktop / web)
- Shortcuts are wired via `CallbackShortcuts` at the Scaffold root (`Focus(autofocus: true)` wrapper so they fire with no other focus). Bindings: `N` = new item (board screen), `T` = toggle marble/table view, `Ctrl/Cmd+N` = new board (home screen).
- Item dialog: plain `Enter` submits, wired via `CallbackShortcuts` around the `AlertDialog` (Flutter has no "default button" concept — without this wrapper Enter only activates the focused button). Multiline `TextField`s (description only) consume Enter as newline before it bubbles; single-line fields (title, back, duration) let it through. `includeRepeats: false` guards against held-Enter double-submit.
- **Title and back are single-line; only description is multiline.** UX rule — keeps Enter-submits predictable everywhere except the one field that actually needs newlines. If you need more room on a flashcard answer, put it in the description (which now renders on the flipped card).
- About dialog lists the shortcuts gated on `kIsWeb || desktop` — Android/iOS builds never show the section.

## Export / Import
- `.pensine` file format spec: see `PENSINE_FORMAT.md`
- **Incoming-file pipeline.** All platforms converge on the same Dart entry point: `home_screen.dart` calls `listenForPendingImports((content) => BoardIO.importContent(...))` after `_load()`. The platform-split in `lib/services/pending_import.dart` picks the right native bridge.
- **Web (PWA):** `web/manifest.json` declares `file_handlers` for `.pensine`. When the PWA is installed, Chromium registers it as an OS handler — tapping a `.pensine` in a messenger / Files app offers the PWA. `web/index.html` wires `window.launchQueue` to capture the file text and hand it to Dart via `window.pensineRegisterImportListener`. Supported: Chromium desktop + Android Chrome. NOT iOS Safari (Web File Handling API is unimplemented).
- **iOS native:** `Info.plist` declares `CFBundleDocumentTypes` claiming the `com.frenchcommando.pensine.workspace` UTI (which `UTExportedTypeDeclarations` defines). `LSSupportsOpeningDocumentsInPlace = NO` is also required (App Store validation rejects with ITMS-90737 otherwise) — Pensine copies imports into local storage rather than editing in place, so NO is the right value. `SceneDelegate.swift` overrides `scene(_:willConnectTo:options:)` + `scene(_:openURLContexts:)` to read the incoming URL and write its contents to `NSTemporaryDirectory()/pensine_incoming.pensine`. Uses `startAccessingSecurityScopedResource()` for files passed from Files/Mail/messengers.
- **Android native:** `AndroidManifest.xml` declares two intent filters. (a) `ACTION_VIEW` with `file://` + `content://` schemes, `application/octet-stream`/`application/json` MIMEs, and `pathPattern` matching `.pensine` (three path-depth variants for Android's non-greedy matcher) — covers "Open with" flows from Files apps and messengers like Telegram. (b) `ACTION_SEND` with the same MIMEs — covers the Android share-sheet flow that WhatsApp and others use. `MainActivity.kt` extracts the URI via `intent.data` (VIEW) or `Intent.EXTRA_STREAM` (SEND, with the Tiramisu+ typed overload), reads via `ContentResolver.openInputStream(...)`, and writes contents to `cacheDir/pensine_incoming.pensine`. Caveat: the SEND filter claims `application/octet-stream` + `application/json` broadly, so Pensine will appear in share sheets for any file of those types — unavoidable since `.pensine` has no registered MIME. Pensine silently ignores non-pensine content via the "Not a valid .pensine file" path.
- **Native → Dart handoff (iOS/Android):** `pending_import_native.dart` checks `getTemporaryDirectory()/pensine_incoming.pensine` on startup (cold launch) and on `AppLifecycleState.resumed` (hot launch when file arrives while app is backgrounded). Reads content, deletes file, fires the import callback. No MethodChannel — the native side only ever writes, Dart only ever reads. Same temp directory on both platforms because `path_provider`'s iOS impl returns `NSTemporaryDirectory()` and Android impl returns `cacheDir`.
- **Limitation (hot-path):** If the app is already in the foreground and a file arrives (rare — user'd have to multitask, return to messenger, tap file), Dart won't pick up the new file until the next resume event. Acceptable for v1.
- **Upgrade path:** Native file associations take precedence when installed. Web PWA handler stays as fallback for users who don't install native.
- **V2 (workspace)**: `pensine_version: 2`, wraps workspace metadata + all its boards — primary export unit
- **V1 (board)**: `pensine_version: 1`, wraps a single `Board.toJson()` — still supported for single-board export
- Import auto-detects v1 vs v2 by checking for `workspace` vs `board` key
- V2 import creates a new workspace with all boards; V1 import prompts which workspace to add the board to
- Export: save file dialog on desktop native, OS share sheet on mobile native (via `share_plus` — WhatsApp/Messenger/Mail/etc. appear as targets). On web/PWA, `board_io_web.dart` gates `navigator.share({files:...})` behind `matchMedia('(pointer: coarse)')` — touch-primary devices (phones, iPadOS Safari which lies about its UA) get the share sheet; pointer-fine devices (desktop/laptop, including touchscreen laptops) always take the anchor-download path. MIME is split between the two paths: `text/plain` for the share sheet (Chrome's Web Share file allow-list rejects `application/octet-stream`), `application/octet-stream` for the anchor download (stops Android Chrome from appending `.txt` to match a `text/plain` declaration). On share throw, `AbortError` (user cancel) is respected; any other error falls through to anchor download so the user still gets their file. Known: on at least one Android Chrome config, the share sheet never fires and export falls straight to the download path — root cause unknown (canShare returning false vs share throwing silently), not diagnosed because surfacing the failure reason needs a user-visible SnackBar, not console logs.
- Import: file picker on all platforms, generates new IDs to avoid collisions. Strict validation in `Board/BoardItem/Lap/Workspace.fromJson` — missing/wrong-typed fields throw `FormatException` surfaced in the snackbar ("Import failed: Board: unknown type ..."); `sizeMultiplier` clamped to [0.1, 5.0]; 10 MB cap applied to both `importFile` bytes and `importContent` string length before any `jsonDecode`.
- Import picker uses `FileType.custom` with `allowedExtensions: ['pensine']` — prevents iOS from surfacing Photos as a source. Requires the `UTExportedTypeDeclarations` entry in `ios/Runner/Info.plist` (UTI `com.frenchcommando.pensine.workspace`); without it, iOS silently falls back to `FileType.any`.
- Packages: `file_picker` (import + desktop save dialog), `share_plus` (mobile share sheet), `web` (web download)
- Implementation in `lib/services/board_io.dart` with conditional imports for web vs native

## License
- Proprietary / All Rights Reserved (see `LICENSE`)

## Build Process

### Android toolchain pinning
- **JDK 25** (Temurin, local + CI via `actions/setup-java@v4`)
- **Gradle 9.4.1** (pinned in `android/gradle/wrapper/gradle-wrapper.properties`) — needed for JDK 25 runtime; JDK 25 support landed in Gradle 9.0
- **AGP 8.13.2** (pinned in `android/settings.gradle.kts`) — last release of the 8.x line. AGP 9.x exists but Flutter stable doesn't yet support AGP 9's new DSL — Flutter's Gradle plugin NPEs when applied under AGP 9. AGP 8.13 is the bridge: old DSL, compatible with Gradle 9.x. Revisit when Flutter ships AGP 9 support (watch https://docs.flutter.dev/release/breaking-changes). Flutter version isn't pinned in this repo (pubspec.yaml only pins Dart SDK); CI uses whatever the `subosito/flutter-action` default is at run time.
- **Kotlin 2.2.20** (pinned in `settings.gradle.kts` via `org.jetbrains.kotlin.android`) — required because AGP 8.x doesn't bundle Kotlin (AGP 9 does).
- Version number mismatch is intentional: Gradle 9 / AGP 8 are independent release streams. Don't "unify" them by downgrading Gradle.

### Android release signing & Play upload
- Upload keystore lives at `C:\Users\Martial\.android\pensine-release.jks` (outside the repo — never commit `.jks` or `key.properties`)
- 4 GitHub Secrets feed `release.yml`'s signing step: `ANDROID_KEYSTORE_BASE64` (base64 of the `.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (=`pensine`), `ANDROID_KEY_PASSWORD`. Workflow decodes to `android/app/pensine-release.jks` and writes `android/key.properties` at build time.
- Play App Signing re-signs with Google's key on upload — our upload key is identity only, not the distribution key. Losing it means resetting the upload key via Play Console, not losing the app.
- Play Console uploads authenticated via Google Cloud service account `pensine-play-ci` — JSON key stored in GitHub Secret `PLAY_STORE_CONFIG_JSON`.
- Play Console → Users & permissions → service account email granted these granular app-level permissions only: "View app information (read-only)", "Release apps to testing tracks", "Release to production, exclude devices, and use Play App Signing". No Admin, no financial, no account-level.
- `bundle exec fastlane android beta` uploads the AAB to the Internal track using the service account JSON.
- After the Play upload, the same job builds a signed release APK and publishes a GitHub Release. Tag is `build-<github.run_number>` (unique per workflow run — no drift, no overwrites); release title is `v<pubspec version> · build <run_number>` (marketing label + identity); APK filename is `pensine-v<version>-build<N>.apk`. Pubspec version is pure flavor/PR labeling — the identity of the build is the run number, which also matches the build number baked into the APK itself. Phone bookmark `github.com/FrenchCommando/pensine/releases/latest` always resolves to the most recent release — the README links to this same URL under "Install on Android". Re-running without bumping pubspec just produces another immutable release row under the same version label. Signed with the upload key, not Play App Signing, so sideloaded installs can't be upgraded by Play installs (signature mismatch) and vice versa.
- Fastfile lives at `fastlane/Fastfile` (repo root), not `android/fastlane/Fastfile`. Fastlane's working directory is the repo root, so artifact paths in the Fastfile are `build/app/outputs/bundle/release/app-release.aab` — **no `../` prefix** (standard Flutter snippets assume the `android/fastlane/` layout and prepend `../`; that's wrong here).

### Play Console listing reference
- Privacy policy URL: `https://frenchcommando.github.io/pensine/privacy.html` (served from `web/privacy.html` via the Pages deploy)
- Marketing / website URL: `https://frenchcommando.github.io/pensine/site/` (landing page in `web/site/index.html`; the Pages root `/` is the live web app itself)
- Target audience: declared **13+** to skip Designed for Families / COPPA flow. The app collects nothing, so no kids-specific disclosures apply, but marketing to under-13s would force the extra review.
- Data safety: declared **no data collected, no data shared** — matches the privacy policy and the actual app (no network calls).
- Screenshot AVD → Play tier: `pixel_7` = phone, `nexus_7` = 7" tablet, `pixel_tablet` = 10" tablet. The `screenshots.yml` matrix produces one artifact per tier.

### Dev
- `flutter run -d windows` (or `-d chrome`, `-d macos`, etc.)

### Icon regeneration (after editing SVG)
- Windows: `tool\generate_icon.bat`
- Unix: `tool/generate_icon.sh`

### Release builds
- Windows: `flutter build windows`
- Android: `flutter build appbundle` (AAB, for Play) or `flutter build apk` (sideloading)
- iOS: `flutter build ipa` (signed, for App Store) or `flutter build ios` (unsigned, for local run)
- Web: `flutter build web`

### Version
- Version defined in `pubspec.yaml` (`version:` field), displayed in about dialog via `package_info_plus`
- Build timestamp passed via `--dart-define=BUILD_DATE=...` in CI; shows "dev" locally by default
- `pubspec.yaml` has only the marketing version (e.g. `version: 1.1.1`) — no `+<build>` suffix. The build number is always injected at build time, never read from pubspec.
- **CI builds inject `github.run_number` as the build number** — iOS via `flutter build ipa --build-number=`, Android via `GITHUB_RUN_NUMBER` in Fastfile + the APK build step, web via `flutter build web --build-number=` in `deploy.yml`. Each workflow has its own independent `run_number` counter, so web and mobile numbers won't match (that's fine — different channels).
- **Local builds fall back to Flutter's default (`1`).** Harmless — local APKs/web builds aren't published anywhere, and the About dialog just shows `1.1.1 (build 1)`.
- Back-to-back release runs publish the same version name with strictly-increasing build numbers, which TestFlight and Play internal track both accept.
- **Bump pubspec only to cut a new marketing version.** Running the release workflow without bumping is normal: Play/TestFlight get a fresh build under the same version name, and a new immutable GitHub Release at `build-<run_number>` appears (version name shown in the release title + APK filename as flavor). Bump the version name when you want testers to see "v1.1.2" as a distinct label.
- **Don't "Re-run failed jobs"** on the release workflow — `github.run_number` stays the same across re-runs (only `run_attempt` increments), so the upload will be rejected as a duplicate build number. Trigger a fresh run instead.

### Shipping a build to a device
- No "submit to store" step — the pipeline is Play internal + TestFlight only (no production). Push commits to main, run the Release workflow from the Actions UI. That's the whole flow.
- **Android (Play internal):** Play Store offers the update automatically within a few minutes. Nudge by opening Play Store → My apps if impatient.
- **iOS (TestFlight):** TestFlight app notifies when Apple finishes processing (~10–30min typical, first build after a plist change can be longer). External testers join via public link `https://testflight.apple.com/join/KDHvbWKH` (also linked from README + landing page); internal team members are added by Apple ID in App Store Connect → TestFlight → Internal Testing.
- **Sideload (Android):** open `github.com/FrenchCommando/pensine/releases/latest` on the phone, tap the APK, install. Signature is the upload key — consistent across your sideloaded builds, but incompatible with Play installs (can't mix on the same device without uninstalling first).
- Native config changes (Info.plist, AndroidManifest) ride along in the binary and take effect after install. No extra store review for Play internal / TestFlight Internal tracks; TestFlight External gets a quick Beta App Review (~minutes after the first approval).

### CI
- `.github/workflows/ci.yml` — runs on push/PR to main: `flutter analyze`, `flutter test`, `flutter build web`
- `.github/workflows/build-ios.yml` — builds iOS (no signing) on push/PR to main
- `.github/workflows/screenshots.yml` — manual trigger; generates store screenshots + preview video (see DEPLOYMENT.md). iOS jobs wrap the test/preview step in `nick-fields/retry@v3` (per-attempt timeout + 1 retry) — `macos-latest` simulators intermittently hang after Xcode build with no output until the job timeout. Different device hangs each run, so it's environmental flake, not a real bug. Android jobs run KVM-accelerated, no flake observed.
- `.github/workflows/release.yml` — manual trigger only (`workflow_dispatch`); uploads to Play internal + TestFlight + publishes signed APK as a GitHub Release tagged `build-<run_number>` (see DEPLOYMENT.md)
- Local composite actions in `.github/actions/`: `setup-flutter` (Flutter SDK + pub get) and `setup-android-emulator-host` (KVM + JDK 25). Caller must run `actions/checkout@v5` immediately before `- uses: ./.github/actions/<name>` — local composite actions are loaded from disk, so the checkout has to happen first.
- Orchestration scripts in `tool/` (`run_screenshot_test.sh`, `run_ios_preview.sh`, `run_android_preview.sh`, `boot_ios_simulator.sh`, `setup_ios_status_bar.sh`, `setup_android_status_bar.sh`, `screenshot_server.py`). Multi-line bash with shared variables must live in a script file because `reactivecircus/android-emulator-runner` runs each YAML `script:` line as a separate `sh -c`.
- All workflows enable `cache: true` on `subosito/flutter-action` (via the composite) to restore Flutter SDK + pub cache across runs
- GitHub Actions use v5 (`actions/checkout@v5`, etc.) for Node.js 24 compatibility
- Free for public repos using standard GitHub-hosted runners (`ubuntu-latest`, `macos-15` for iOS release/build, `macos-latest` for screenshots)

### CD
- `.github/workflows/deploy.yml` — deploys to GitHub Pages after CI succeeds on main (uses `workflow_run`)

### PWA
- Flutter web builds include PWA support (manifest.json + service worker) by default
- Android: browser prompts install natively; PWA storage is tied to the installing browser (clear site data in browser settings to reset)
- iOS: manual "Add to Home Screen" (install banner guides users)

### Local Testing (WSL2)
- Local-only scripts live in `local/` (separate from `tool/`, which holds CI/shared scripts):
  - `setup_wsl_android.sh` — idempotent installer (Temurin JDK 25 via Adoptium apt, Android SDK API 35 x86_64, Flutter SDK, AVDs)
  - `boot_android_emulator.sh` — boots the AVD and configures the status bar
  - `wsl_env.sh` — canonical env (JAVA_HOME, ANDROID_HOME, FLUTTER_HOME, PATH); sourced by setup, the `.bat`, and `~/.bashrc`
  - `screenshot_test.bat` — pixel_7 (phone), `screenshot_tablet7.bat` — nexus_7 (7" tablet), `screenshot_tablet.bat` — pixel_tablet (10" tablet). One .bat per device by design — swiftshader can't reliably finish the full suite back-to-back, so capturing all three store tiers in one go is the `screenshots.yml` workflow's job (KVM matrix run on CI)
  - `preview_test.bat` — setup + boot + preview walkthrough recording for `pixel_7`
  - `local/IOS/` — macOS VM setup via OSX-KVM (QEMU) for iOS testing; see scripts inside
- Requires WSL2 with nested virtualization (toggle in the WSL Settings app → System tab)
- Workflow from cmd in repo root: `local\screenshot_test.bat`
- The screenshot and preview test scripts (`tool/run_screenshot_test.sh`, `tool/run_android_preview.sh`) are the same scripts CI runs — no env-specific forks
- Local emulator uses swiftshader (software renderer) — adequate for debugging test logic but too slow for sustained physics rendering; full suite runs reliably on CI with KVM hardware acceleration

### Not yet set up
- `.pensine` file association on desktop: Windows file type registry (needs installer work, deferred until a packaged Windows build exists), macOS `LSItemContentTypes` + Info.plist (no macOS build targeted yet), Linux `.desktop` MimeType entry (same). iOS + Android + web are all wired.

## Feature Graphic
- Play Store banner (1024x500) in `assets/feature_graphic.svg`
- Yellow background with mortar bowl and scattered marbles
- Convert to PNG via `tool\generate_feature_graphic.bat`

## App Store Deployment

See `DEPLOYMENT.md` for full details.
