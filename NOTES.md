# Notes

## Windows Setup
- Flutter requires Developer Mode enabled (`ms-settings:developers`) for symlink support when building with plugins.

## Known Issues
- `Failed to update ui::AXTree` errors on Windows — known Flutter bug with accessibility bridge during rapid widget updates (60fps ticker). Harmless, ignore.

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
- **Flashcards**: tap to flip, tap again = wrong (flips back, grows), double-tap = correct (shrinks to net), flip-all button, reset button
- **Steps (checklist)**: sequential order — active step inflates and shows description, numbered marbles, tap active step to complete, tap any other marble to jump there (sets everything before it as done), reset button
- **Timer**: like checklist + stopwatch overlay. Timer starts when first step is completed, shows total elapsed and per-step time. Each advance appends a `Lap` (itemId + elapsedSeconds + recordedAt) to `Board.laps`. Bottom-right shows the lap log. Reset clears timer state but **leaves laps as history** (laps accumulate across runs).
- **Countdown**: like checklist + per-step countdown. Each item has `durationSeconds`; auto-advances when countdown hits zero. Marbles still tappable to jump around. Duration field in add/edit dialogs. Auto-advance also appends a `Lap`. Reset clears countdown state, leaves laps.
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

## Export / Import
- `.pensine` file format spec: see `PENSINE_FORMAT.md`
- **V2 (workspace)**: `pensine_version: 2`, wraps workspace metadata + all its boards — primary export unit
- **V1 (board)**: `pensine_version: 1`, wraps a single `Board.toJson()` — still supported for single-board export
- Import auto-detects v1 vs v2 by checking for `workspace` vs `board` key
- V2 import creates a new workspace with all boards; V1 import prompts which workspace to add the board to
- Export: save file dialog on desktop, file download on web, share sheet on mobile
- Import: file picker on all platforms, generates new IDs to avoid collisions
- Import picker uses `FileType.custom` with `allowedExtensions: ['pensine']` — prevents iOS from surfacing Photos as a source. Requires the `UTExportedTypeDeclarations` entry in `ios/Runner/Info.plist` (UTI `com.frenchcommando.pensine.workspace`); without it, iOS silently falls back to `FileType.any`.
- Packages: `file_picker` (import + desktop save dialog), `share_plus` (mobile share sheet), `web` (web download)
- Implementation in `lib/services/board_io.dart` with conditional imports for web vs native

## License
- Proprietary / All Rights Reserved (see `LICENSE`)

## Build Process

### Android toolchain pinning
- **JDK 25** (Temurin, local + CI via `actions/setup-java@v4`)
- **Gradle 9.4.1** (pinned in `android/gradle/wrapper/gradle-wrapper.properties`) — needed for JDK 25 runtime; JDK 25 support landed in Gradle 9.0
- **AGP 8.13.2** (pinned in `android/settings.gradle.kts`) — last release of the 8.x line. AGP 9.x (9.1.1 latest) exists but Flutter stable (3.41.7 as of 2026-04) doesn't yet support AGP 9's new DSL — Flutter's Gradle plugin NPEs when applied under AGP 9. AGP 8.13 is the bridge: old DSL, compatible with Gradle 9.x. Revisit when Flutter ships AGP 9 support (watch https://docs.flutter.dev/release/breaking-changes).
- **Kotlin 2.2.20** (pinned in `settings.gradle.kts` via `org.jetbrains.kotlin.android`) — required because AGP 8.x doesn't bundle Kotlin (AGP 9 does).
- Version number mismatch is intentional: Gradle 9 / AGP 8 are independent release streams. Don't "unify" them by downgrading Gradle.

### Android release signing & Play upload
- Upload keystore lives at `C:\Users\Martial\.android\pensine-release.jks` (outside the repo — never commit `.jks` or `key.properties`)
- 4 GitHub Secrets feed `release.yml`'s signing step: `ANDROID_KEYSTORE_BASE64` (base64 of the `.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (=`pensine`), `ANDROID_KEY_PASSWORD`. Workflow decodes to `android/app/pensine-release.jks` and writes `android/key.properties` at build time.
- Play App Signing re-signs with Google's key on upload — our upload key is identity only, not the distribution key. Losing it means resetting the upload key via Play Console, not losing the app.
- Play Console uploads authenticated via Google Cloud service account `pensine-play-ci` — JSON key stored in GitHub Secret `PLAY_STORE_CONFIG_JSON`.
- Play Console → Users & permissions → service account email granted these granular app-level permissions only: "View app information (read-only)", "Release apps to testing tracks", "Release to production, exclude devices, and use Play App Signing". No Admin, no financial, no account-level.
- `bundle exec fastlane android beta` uploads the AAB to the Internal track using the service account JSON.
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
- Android: `flutter build apk`
- iOS: `flutter build ios`
- Web: `flutter build web`

### Version
- Version defined in `pubspec.yaml` (`version:` field), displayed in about dialog via `package_info_plus`
- Build timestamp passed via `--dart-define=BUILD_DATE=...` in CI; shows "dev" locally by default

### CI
- `.github/workflows/ci.yml` — runs on push/PR to main: `flutter analyze`, `flutter test`, `flutter build web`
- `.github/workflows/build-ios.yml` — builds iOS (no signing) on push/PR to main
- `.github/workflows/screenshots.yml` — manual trigger; generates store screenshots + preview video (see DEPLOYMENT.md)
- `.github/workflows/release.yml` — tag-push (`v*.*.*`) or manual; uploads to Play internal + TestFlight (see DEPLOYMENT.md)
- Local composite actions in `.github/actions/`: `setup-flutter` (Flutter SDK + pub get) and `setup-android-emulator-host` (KVM + JDK 25). Caller must run `actions/checkout@v5` immediately before `- uses: ./.github/actions/<name>` — local composite actions are loaded from disk, so the checkout has to happen first.
- Orchestration scripts in `tool/` (`run_screenshot_test.sh`, `run_ios_preview.sh`, `run_android_preview.sh`, `boot_ios_simulator.sh`, `setup_ios_status_bar.sh`, `setup_android_status_bar.sh`, `screenshot_server.py`). Multi-line bash with shared variables must live in a script file because `reactivecircus/android-emulator-runner` runs each YAML `script:` line as a separate `sh -c`.
- All workflows enable `cache: true` on `subosito/flutter-action` (via the composite) to restore Flutter SDK + pub cache across runs
- GitHub Actions use v5 (`actions/checkout@v5`, etc.) for Node.js 24 compatibility
- Free for public repos using standard GitHub-hosted runners (`ubuntu-latest`, `macos-latest`)

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
- `.pensine` file association — register the app as handler so tapping a `.pensine` file opens it directly. iOS: UTI is declared via `UTExportedTypeDeclarations` (for the picker filter) but `CFBundleDocumentTypes` is not, so "open with Pensine" from Files doesn't work yet. Android intent filters, Windows file type registry, macOS UTI: all still pending. Do this when native apps are fully deployed.

## Feature Graphic
- Play Store banner (1024x500) in `assets/feature_graphic.svg`
- Yellow background with mortar bowl and scattered marbles
- Convert to PNG via `tool\generate_feature_graphic.bat`

## App Store Deployment

See `DEPLOYMENT.md` for full details.
