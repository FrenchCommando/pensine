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
- **Marble label on countdown boards (non-start items):** painted below center as `N (x/y)` where `y = durationSeconds` and `x` is `durationSeconds` before the step runs, the live remaining value while it's active (driven by `board_screen.dart::_countdownRemainingForActive()` on the `_overlayTick` ValueNotifier — physics ticker may be idle while the active marble is static, so MarbleBoard is wrapped in a `ValueListenableBuilder<int>` for countdown boards to force one rebuild per second), and `0` when the step is done. Timer boards and checklists just show `N` — they have no duration per item.
- **Start marble convention (timer/countdown)**: item at index 0 arms the clock but is never logged as a lap — for both the manual-tap (timer) and auto-fire (countdown) paths. Treat it as a dedicated "Start" sentinel. Examples `Flight Log` and `Tabata` in `_defaults()` use this (Engine start / Shutdown; Warm-up / Cool-down). Its marble label reads `tap to start` before tap, and collapses to `1` (just the index) after — skips the `(x/y)` countdown format even on countdown boards since the sentinel itself doesn't run a clock.
- **Timer/countdown elapsed is session-scoped, not persisted.** `BoardScreen._initTimerState` restarts the clock at `DateTime.now()` on re-entry if any item is `done`. Leaving and returning to a partially-completed timer board shows 00:00 again. Intentional: persisted `Board.laps` are the source of truth for "what happened"; the live overlay is scratchpad state. Don't rewire this into persisted elapsed without also deciding how to render resumed vs. fresh runs.
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
- Boards can be reordered within a workspace by dragging the handle icon on the right of each board tile (no long-press — `ReorderableDragStartListener` wraps only the handle, keeping `ListTile.onTap` free to open the board). Cross-workspace moves go through the popup menu's "Move to workspace". Routed through `BoardsController.reorderBoards` which takes the full global order; `_reorderBoardsWithinWorkspace` in `home_screen.dart` preserves other workspaces' positions and only shuffles the dragged workspace's slots.
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
- Shortcuts wired via `CallbackShortcuts` at the Scaffold root (`Focus(autofocus: true)` wrapper so they fire with no other focus).
  - **Home screen:** `Ctrl/Cmd+N` = new board.
  - **Board screen (all board types):** `N` = new item, `T` = toggle marble/table view, `S` = shake marbles (no-op in table mode), `R` = reset (clears done flags, laps, flip state, timers — no-op if nothing to reset), `D` = toggle dark/light theme, `A` = about dialog.
  - Single-letter bindings are swallowed by focused TextFields, so typing `R` in an item dialog inserts `R` (doesn't fire reset). Dialog route scope also traps shortcuts away from the board scaffold.
- **Item dialog keyboard nav:** `Tab` moves through title → description → back → duration → color picker (as one stop) → size slider → buttons. `Enter` submits (via the dialog's own `CallbackShortcuts`; Flutter has no "default button" concept). Multiline description consumes Enter as newline; single-line fields let it through. `includeRepeats: false` guards against held-Enter double-submit.
- **Color picker is a radio group**, not N-tab-stops. Tab enters, arrow keys (↑↓←→) move selection + wrap at edges, Tab leaves. Selected swatch's ring thickens while the group has focus so users can see they're in it. Same widget used everywhere a color is picked (new/edit item, workspace color).
- **Table mode is keyboard-navigable.** One tab stop for the whole table. `↑/↓` moves a selection highlight (focus ring + tinted row bg + colored left edge), `E` opens the edit dialog on the selected row, `Enter/Space` activates (toggles done / advances step / etc. — matches mouse click). Selection survives reorder and clamps on delete.
- **Title and back are single-line; only description is multiline.** UX rule — keeps Enter-submits predictable everywhere except the one field that actually needs newlines. If you need more room on a flashcard answer, put it in the description (which now renders on the flipped card).
- About dialog lists the shortcuts gated on `kIsWeb || desktop` — Android/iOS builds never show the section.

## Desktop pointer UX
- `lib/utils/platform.dart::isDesktopUX` = true on native Windows/macOS/Linux and on web when `defaultTargetPlatform` reports a desktop OS (web-mobile browsers report android/iOS, so they stay touch). Drives the "right-click not long-press" swap below.
- **Edit gesture split.** Marble mode: right-click (`onSecondaryTapDown`) on a marble opens the edit dialog; right-click empty space opens the new-item dialog. Table mode: right-click (`onSecondaryTap`) on a row opens edit, right-click empty-state opens new-item. Long-press is disabled on desktop so a mouse click-and-hold doesn't fire the wrong action. On touch (android/iOS/web-mobile) long-press still works, no right-click wired.
- Empty-state hint text adapts (`Right-click to add something.` on desktop vs `Long-press to add something.` on touch).

## Export / Import
- `.pensine` file format spec: see `PENSINE_FORMAT.md`
- **Incoming-file pipeline.** All platforms converge on the same Dart entry point: `home_screen.dart` calls `listenForPendingImports((content) => BoardIO.importContent(...))` after `_load()`. The platform-split in `lib/services/pending_import.dart` picks the right native bridge.
- **Web (PWA):** `web/manifest.json` declares `file_handlers` for `.pensine`. When the PWA is installed, Chromium registers it as an OS handler — tapping a `.pensine` in a messenger / Files app offers the PWA. `web/index.html` wires `window.launchQueue` to capture the file text and hand it to Dart via `window.pensineRegisterImportListener`. Supported: Chromium desktop + Android Chrome. NOT iOS Safari (Web File Handling API is unimplemented).
- **iOS native:** `Info.plist` declares `CFBundleDocumentTypes` claiming the `com.frenchcommando.pensine.workspace` UTI (which `UTExportedTypeDeclarations` defines). `LSSupportsOpeningDocumentsInPlace = NO` is also required (App Store validation rejects with ITMS-90737 otherwise) — Pensine copies imports into local storage rather than editing in place, so NO is the right value. `SceneDelegate.swift` overrides `scene(_:willConnectTo:options:)` + `scene(_:openURLContexts:)` to read the incoming URL and write its contents to `NSTemporaryDirectory()/pensine_incoming.pensine`. Uses `startAccessingSecurityScopedResource()` for files passed from Files/Mail/messengers.
- **Android native:** `AndroidManifest.xml` declares two intent filters. (a) `ACTION_VIEW` with `file://` + `content://` schemes, `application/octet-stream`/`application/json` MIMEs, and `pathPattern` matching `.pensine` (three path-depth variants for Android's non-greedy matcher) — covers "Open with" flows from Files apps and messengers like Telegram. (b) `ACTION_SEND` with the same MIMEs — covers the Android share-sheet flow that WhatsApp and others use. `MainActivity.kt` extracts the URI via `intent.data` (VIEW) or `Intent.EXTRA_STREAM` (SEND, with the Tiramisu+ typed overload), reads via `ContentResolver.openInputStream(...)`, and writes contents to `cacheDir/pensine_incoming.pensine`. Caveat: the SEND filter claims `application/octet-stream` + `application/json` broadly, so Pensine will appear in share sheets for any file of those types — unavoidable since `.pensine` has no registered MIME. Pensine silently ignores non-pensine content via the "Not a valid .pensine file" path.
- **Native → Dart handoff (iOS/Android/Windows):** `pending_import_native.dart` checks `getTemporaryDirectory()/pensine_incoming.pensine` on startup (cold launch) and on `AppLifecycleState.resumed` (hot launch when file arrives while app is backgrounded). Reads content, deletes file, fires the import callback. No MethodChannel — the native side only ever writes, Dart only ever reads. Same temp directory on every platform: iOS `NSTemporaryDirectory()`, Android `cacheDir`, Windows `GetTempPathW()` (= dart:io's `Directory.systemTemp`).
- **Windows native:** `windows/runner/utils.cpp::HandleIncomingPensineFile` runs in `wWinMain` before the Flutter window is created. Scans `argv` for the first `.pensine` path, copies its bytes (capped at 10 MB to match the Dart import cap) into `%TEMP%\pensine_incoming.pensine`. The Inno Setup installer registers `.pensine` → `Pensine.Workspace` ProgId → `pensine.exe "%1"` so double-clicks land here. Plain-zip users don't get the file association — only installer users. No single-instance guard: double-clicking a `.pensine` while Pensine is already running launches a second window that imports. Acceptable for v1. End-to-end flow verified on Windows 2026-04-20 (install → double-click `.pensine` in Explorer → new workspace on home).
- **Limitation (hot-path, split-screen only):** Dart polls the cache file on cold start and on `AppLifecycleState.resumed`. The standard background→tap→foreground flow goes through paused→resumed, so files get picked up. The narrow case that doesn't: split-screen / multi-window on tablets, where Pensine and the messenger are both visible — Pensine never loses focus, no resume event fires, and the file sits in cache until the next real resume. Won't fix — affects tablet split-screen users only, and tapping in/out of Pensine triggers the resume that drains the file.
- **Upgrade path:** Native file associations take precedence when installed. Web PWA handler stays as fallback for users who don't install native.
- **V2 (workspace)**: `pensine_version: 2`, wraps workspace metadata + all its boards — primary export unit
- **V1 (board)**: `pensine_version: 1`, wraps a single `Board.toJson()` — still supported for single-board export
- Import auto-detects v1 vs v2 by checking for `workspace` vs `board` key
- V2 import creates a new workspace with all boards; V1 import prompts which workspace to add the board to
- Export: save file dialog on desktop native, OS share sheet on mobile native (via `share_plus` — WhatsApp/Messenger/Mail/etc. appear as targets). On web/PWA, `board_io_web.dart` gates `navigator.share({files:...})` behind `matchMedia('(pointer: coarse)')` — touch-primary devices (phones, iPadOS Safari which lies about its UA) get the share sheet; pointer-fine devices (desktop/laptop, including touchscreen laptops) always take the anchor-download path. MIME is split between the two paths: `text/plain` for the share sheet (Chrome's Web Share file allow-list rejects `application/octet-stream`), `application/octet-stream` for the anchor download (stops Android Chrome from appending `.txt` to match a `text/plain` declaration). On share throw, `AbortError` (user cancel) is respected; any other error falls through to anchor download so the user still gets their file.
- Import: file picker on all platforms, generates new IDs to avoid collisions. Strict validation in `Board/BoardItem/Lap/Workspace.fromJson` — missing/wrong-typed fields throw `FormatException` surfaced in the snackbar ("Import failed: Board: unknown type ..."); `sizeMultiplier` clamped to [0.1, 5.0]; 10 MB cap applied to both `importFile` bytes and `importContent` string length before any `jsonDecode`.
- Import picker uses `FileType.custom` with `allowedExtensions: ['pensine']` — prevents iOS from surfacing Photos as a source. Requires the `UTExportedTypeDeclarations` entry in `ios/Runner/Info.plist` (UTI `com.frenchcommando.pensine.workspace`); without it, iOS silently falls back to `FileType.any`.
- Packages: `file_picker` (import + desktop save dialog), `share_plus` (mobile share sheet), `web` (web download)
- Implementation in `lib/services/board_io.dart` with conditional imports for web vs native

## Architecture

- **`BoardsController`** (`lib/controllers/boards_controller.dart`) is a `ChangeNotifier` that owns workspaces, boards, collapsed state, loading flag, and the persistence calls. `HomeScreen` holds one, listens for changes, and renders. Don't call `LocalStorage` from screens — go through the controller so mutations are atomic (in-memory + disk + notify).
- **`applyBoardTap`** (`lib/behavior/board_tap.dart`) is a pure function that encodes per-board-type tap rules. Takes `(Board, BoardItem, stepStart?)`, mutates `board` in place, returns a `BoardTapOutcome` describing what the screen should do next (fire haptics, start/stop/freeze timers, persist). The screen stays thin — it's an orchestrator, not a state machine. `test/board_tap_test.dart` exercises every tap variant directly (no widget pump).
- **Default seed data** lives in `lib/data/defaults.dart` as `buildDefaults()`. Used on first launch and after Reset. Pure data — no `build()`, no `BuildContext`.
- **Adding a new board type**: (a) add the enum value + extension metadata in `lib/models/board.dart`; (b) add one case to the switch in `applyBoardTap`; (c) add any type-specific UI branches in `board_screen.dart` / `items_table.dart` / `marble_board.dart` only if the visual/interaction is genuinely different. The pre-refactor pattern of switch statements scattered across 5 files is the anti-pattern to avoid.

## Testing

Three layers, each with a home:

- **Unit + widget tests** — `test/` directory, run via `flutter test` (~20s, 94 tests). Gated on push/PR by `.github/workflows/ci.yml`. Covers: model serialization + negative `fromJson` cases, `.pensine` v1/v2 golden fixtures, `LocalStorage` round-trip / race regression / corrupted-file resilience, `ItemsTable` rendering, `BoardScreen` tap transitions (todo toggle, sequential advance/rewind, timer lap rules, start-marble sentinel), full-app boot + nav flow (`test/app_flow_test.dart`), dialog disposal regression (`test/dialog_disposal_test.dart`).
- **Integration tests** — `integration_test/*.dart`, run via `flutter drive` on real targets. Gated on push/PR by `.github/workflows/integration.yml` with four parallel jobs (chrome / android / ios / windows). `smoke_test.dart` runs on every job (boot → open board → back, defaults render, create board with real platform channels). `pending_import_test.dart` runs on Windows only — pre-populates `%TEMP%\pensine_incoming.pensine` with a v2 envelope and asserts the cold-launch import pipeline (`windows/runner/utils.cpp::HandleIncomingPensineFile` → `pending_import_native.dart`) surfaces the imported workspace on home.
- **Windows integration tests are CI-only.** Local Windows runs share `%APPDATA%`, `%TEMP%`, and shared_preferences with the installed Pensine, so they leak the test's "Integration Test Workspace" into the user's real boards. Two-layer guard: (a) `tool/run_windows_integration.sh` checks `CI=true` before invoking `flutter drive` — instant rejection without paying the ~30s build cost. CI sets `CI=true` automatically; this is what `integration.yml`'s `windows` job uses. (b) `requireCIOnWindows()` in `integration_test/test_helpers.dart` fires inside the test main() as defense-in-depth if someone bypasses the script with raw `flutter drive`. Override for local debugging by setting `CI=true` in the shell — accepts the data pollution.
- **Artifact generation** — `integration_test/screenshot_test.dart` + `preview_test.dart`, run via `.github/workflows/artifacts.yml` (manual trigger only, on iOS + Android emulators/simulators). Produces store screenshots + preview videos. Not a regression gate.

### Leak tracking

- `test/flutter_test_config.dart` auto-configures `LeakTesting.settings.withTrackedAll()` for every test in `test/`. Any `Disposable` (TextEditingController, AnimationController, ValueNotifier, FocusNode, Ticker, TextPainter, ScrollController, …) that becomes GC-unreachable without `dispose()` fails the test.
- Ignored: `ImageStreamCompleterHandle` + `_LiveImage` — framework-internal image-cache singletons with no user-land dispose contract.
- **TextPainter in paint loops must be disposed.** `TextPainter` holds native `ui.Paragraph` buffers — undisposed painters leak native memory even after Dart-side GC. `marble_board.dart` creates 7 per-paint (title, description, fit-measurement, body text, flashcard arrow, step number, net count); all are disposed after their final `paint()` / `layout()`. New painters added to paint code must follow the same pattern or leak_tracker will fail CI. Found this leak on first leak-tracker run.
- **TextEditingController in dialogs must live in a StatefulWidget.** The canonical Flutter pattern: dialog content is a `StatefulWidget`; its `State` owns the controller fields and disposes them in `State.dispose()`. `.whenComplete(controller.dispose)` and `try { await showDialog } finally { controller.dispose() }` look correct but race the route's exit transition — on heavy parent trees (the full home screen, not the isolated board-screen test), the TextField rebuilds during the fade-out and hits "used after disposed." `_NewBoardDialog`, `_PromptNameDialog`, `_ItemDialog` are the three canonical examples in the codebase. `test/dialog_disposal_test.dart` drives multiple open/close cycles with a full exit-animation pump as the regression guard — it was the 500ms pumping in that test that surfaced the race originally.

### Principle

Every bugfix or feature ships with a test. Unit/widget if `flutter_tester` can see it; integration if it needs a real platform channel. If no tool can observe it, that's a signal — question whether the bug actually matters, or find the tool (leak_tracker was the answer for the dispose class of bugs).

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
- Screenshot AVD → Play tier: `pixel_7` = phone, `nexus_7` = 7" tablet, `pixel_tablet` = 10" tablet. The `artifacts.yml` matrix produces one artifact per tier.

### Dev
- `flutter run -d windows` (or `-d chrome`, `-d macos`, etc.)

### Icon regeneration (after editing SVG)
- Windows: `tool\generate_icon.bat`
- Unix: `tool/generate_icon.sh`

### Release builds
- Windows: `flutter build windows` (bare exe + DLLs) or `dart run msix:create --store` (MSIX for Microsoft Store — requires identity flags, see DEPLOYMENT.md)
- Android: `flutter build appbundle` (AAB, for Play) or `flutter build apk` (sideloading)
- iOS: `flutter build ipa` (signed, for App Store) or `flutter build ios` (unsigned, for local run)
- Web: `flutter build web`

### Windows (plain zip + Inno Setup installer — current channels)
- `release.yml`'s `windows-release` job builds `flutter build windows --release`, then produces two artifacts: the plain zip of `build\windows\x64\runner\Release\*` (extract-and-run) and an Inno Setup installer (Start Menu entry, `.pensine` file association, uninstaller). Both attached to the GitHub Release tagged `build-<run_number>` alongside the APK. Both unsigned — SmartScreen warns once at install time for the installer, every fresh extract for the zip.
- Inno Setup script lives at `windows/installer/pensine.iss`. Per-user install (`PrivilegesRequired=lowest`) so no admin prompt, registry writes go to HKCU. Version + build number injected via `/DAppVersion=...` `/DBuildNumber=...` flags from CI.
- **Requirements** advertised on README + landing page: Windows 10 version 1809 (build 17763) or later, on x64 or ARM64 Windows 11. Enforced by `MinVersion=10.0.17763` + `ArchitecturesAllowed=x64compatible` in the .iss; both failure paths route through a customized `WindowsVersionNotSupported` message that names what they need instead of Inno's cryptic default.
- `ci.yml`'s `build-windows` job additionally uploads the zip + installer as workflow artifacts on every push/PR so any green build is downloadable without cutting a release. See DEPLOYMENT.md for the user-facing install steps.
- Installer assumes `ISCC.exe` is on PATH on `windows-latest` runners (preinstalled in current GitHub-hosted Windows images). If a runner image change breaks this, install via `choco install innosetup -y` before the build step.

### Windows MSIX
- `msix_config` in `pubspec.yaml` holds non-identity fields only (display_name, logo_path, architecture, store mode, output path). Identity fields (`publisher`, `publisher_display_name`, `identity_name`) live in GitHub Secrets and are injected via CLI flags in CI — same pattern as Android keystore / iOS cert, treats identifying Store values as secrets even though they're technically visible post-publish.
- MSIX version: 4-part `a.b.c.d`; Store requires the 4th part to be `0`. CI uses `<pubspec version>.0`, so every Store upload needs a pubspec version bump (Store rejects duplicate versions — differs from Play internal / TestFlight which accept same version name with different build numbers).
- Output: `build/windows/msix/pensine.msix`, renamed to `pensine-v<version>-build<N>.msix` and uploaded as a workflow artifact. Download from Actions UI and upload manually to Partner Center until Submission API automation lands.
- MSIX built with `--store` is unsigned — Microsoft re-signs on upload, so sideload installs of the CI artifact won't work without re-signing locally. If we ever want sideloadable Windows builds (pre-Store testing on someone else's machine), add a separate self-signed build path.
- `.pensine` file association on Windows: shipped via Inno Setup (`windows/installer/pensine.iss`) — installer-only, plain-zip users still need the in-app file picker.
- Local copy of Partner Center values lives at `C:\Users\Martial\.msstore\secrets.env` (outside the repo — mirrors `.ios\` and `.android\` conventions for per-platform signing/identity material). Single `KEY=VALUE` file with `MSIX_PUBLISHER_DISPLAY_NAME`, `MSIX_IDENTITY_NAME`, `MSIX_PUBLISHER`, `MSIX_STORE_ID`. Source-before-local-test pattern: `set -a && source /c/Users/Martial/.msstore/secrets.env && set +a` then `dart run msix:create --store` with the env vars as flags. Purpose is diff-against-CI: GitHub masks secret values in workflow logs, so the local file is the only way to know *what* you uploaded when a Category-3 failure (format-valid but wrong) comes back from Partner Center. Keep GitHub Secrets and the local file in sync manually after each Partner Center rotation.

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
- **Windows (sideload zip):** open the same releases/latest page on Windows, download the `*-windows.zip`, extract, run `pensine.exe`. SmartScreen warns on first launch — click "More info → Run anyway." No installer, no uninstaller (just delete the folder). Primary Windows channel until Partner Center unblocks.
- Native config changes (Info.plist, AndroidManifest) ride along in the binary and take effect after install. No extra store review for Play internal / TestFlight Internal tracks; TestFlight External gets a quick Beta App Review (~minutes after the first approval).

### CI
- `.github/workflows/ci.yml` — runs on push/PR to main as parallel jobs: `analyze` (flutter analyze), `test` (flutter test), `build-web`, `build-ios` (no-codesign compile), `build-windows` (flutter build windows + zip artifact + optional MSIX), and `validate-msix` (WACK, gated on MSIX being built). `deploy.yml` triggers on the overall CI workflow success. MSIX build + WACK gate on the `MSIX_PUBLISHER` secret — skip cleanly until Partner Center account lands, auto-activate once secrets land.
- `.github/workflows/artifacts.yml` — manual trigger; generates store screenshots + preview video (see DEPLOYMENT.md). iOS jobs wrap the test/preview step in `nick-fields/retry@v3` (per-attempt timeout + 1 retry) — `macos-latest` simulators intermittently hang after Xcode build with no output until the job timeout. Different device hangs each run, so it's environmental flake, not a real bug. Android jobs run KVM-accelerated, no flake observed.
- `.github/workflows/integration.yml` — runs on push/PR to main; three parallel jobs (chrome / android / ios) each run `flutter drive` against `integration_test/smoke_test.dart` on their respective platform. Complements `ci.yml` (unit/widget tests on `flutter_tester`) by exercising real platform channels: actual `shared_preferences`, web `dart:html` bindings, Android/iOS native lifecycle. Chrome uses `browser-actions/setup-chrome@v2` + chromedriver; Android uses `reactivecircus/android-emulator-runner@v2` (KVM) with the same pixel_7 profile as `artifacts.yml`; iOS uses `macos-latest` + `tool/boot_ios_simulator.sh` wrapped in `nick-fields/retry@v3` (same flake mitigation as artifacts.yml). Wall time ~10-15 min dominated by iOS Xcode build.
- **Android integration `script:` must stay on one line.** `reactivecircus/android-emulator-runner@v2` runs each line of the `script:` value as a separate `sh -c` invocation. A multi-line `flutter drive` with `\` continuations gets split — `sh` sees the trailing `\` as a literal argument and fails with `Target file "\" not found.` Keep the whole `flutter drive` on one YAML line (per-line command). Same rule is why `artifacts.yml`'s Android jobs delegate to `tool/run_screenshot_test.sh` rather than inlining multi-line bash.
- `.github/workflows/release.yml` — manual trigger only (`workflow_dispatch`); `android-release` uploads to Play internal + publishes signed APK as a GitHub Release tagged `build-<run_number>`, `ios-release` uploads to TestFlight, `windows-release` builds + zips Windows release and appends the zip to the same GitHub Release (see DEPLOYMENT.md)
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
  - `screenshot_test.bat` — pixel_7 (phone), `screenshot_tablet7.bat` — nexus_7 (7" tablet), `screenshot_tablet.bat` — pixel_tablet (10" tablet). One .bat per device by design — swiftshader can't reliably finish the full suite back-to-back, so capturing all three store tiers in one go is the `artifacts.yml` workflow's job (KVM matrix run on CI)
  - `preview_test.bat` — setup + boot + preview walkthrough recording for `pixel_7`
  - `local/IOS/` — macOS VM setup via OSX-KVM (QEMU) for iOS testing; see scripts inside
- Requires WSL2 with nested virtualization (toggle in the WSL Settings app → System tab)
- Workflow from cmd in repo root: `local\screenshot_test.bat`
- The screenshot and preview test scripts (`tool/run_screenshot_test.sh`, `tool/run_android_preview.sh`) are the same scripts CI runs — no env-specific forks
- Local emulator uses swiftshader (software renderer) — adequate for debugging test logic but too slow for sustained physics rendering; full suite runs reliably on CI with KVM hardware acceleration

### Not yet set up
- `.pensine` file association on macOS (no macOS build targeted yet) + Linux `.desktop` MimeType entry (same). iOS + Android + web + Windows (installer channel) are all wired.

## Feature Graphic
- Play Store banner (1024x500) in `assets/feature_graphic.svg`
- Yellow background with mortar bowl and scattered marbles
- Convert to PNG via `tool\generate_feature_graphic.bat`

## App Store Deployment

See `DEPLOYMENT.md` for full details.
