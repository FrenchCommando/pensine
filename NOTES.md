# Notes

## Windows Setup
- Flutter requires Developer Mode enabled (`ms-settings:developers`) for symlink support when building with plugins.

## Known Issues
- `Failed to update ui::AXTree` errors on Windows — known Flutter bug with accessibility bridge during rapid widget updates (60fps ticker). Harmless, ignore.

## Web Deployment
- GitHub Pages: `https://frenchcommando.github.io/pensine/`
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
- PNG is gitignored — SVG is the source of truth

## Board Interactions
- **Thoughts**: tap to expand/collapse, long-press to edit
- **To-do**: tap to catch in net (done), long-press to edit, reset button releases all
- **Flashcards**: tap to flip, tap again = wrong (flips back, grows), double-tap = correct (shrinks to net), flip-all button, reset button
- **Steps (checklist)**: sequential order only — active step inflates and shows description, numbered marbles, tap to complete next step, reset button
- **All boards**: drag to fling, long-press empty space to add, shake button scatters marbles

## UI
- Dark/light theme toggle (persisted via `shared_preferences`), available on all screens
- About dialog accessible from all screens, includes "Reset data" to restore default example boards
- Default example boards are hardcoded in `home_screen.dart` (`_defaultBoards()`), used on first launch and reset
- Marble/net sizes scale with screen size (responsive, no hardcoded pixel values)
- Marble diameter capped at 80% of shortest screen side
- Expanded thoughts bubble capped to fit screen
- Text in marbles auto-shrinks to fit
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
- Quicksand font bundled in `assets/fonts/` (no internet needed on first launch)

## Export / Import
- `.pensine` file format spec: see `PENSINE_FORMAT.md`
- Versioned JSON envelope (`pensine_version: 1`) wrapping `Board.toJson()`
- Export: save file dialog on desktop, file download on web, share sheet on mobile
- Import: file picker on all platforms, generates new IDs to avoid collisions
- Packages: `file_picker` (import + desktop save dialog), `share_plus` (mobile share sheet), `web` (web download)
- Implementation in `lib/services/board_io.dart` with conditional imports for web vs native

## License
- Proprietary / All Rights Reserved (see `LICENSE`)

## Build Process

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
- GitHub Actions use v5 (`actions/checkout@v5`, etc.) for Node.js 24 compatibility

### CD
- `.github/workflows/deploy.yml` — deploys to GitHub Pages after CI succeeds on main (uses `workflow_run`)

### PWA
- Flutter web builds include PWA support (manifest.json + service worker) by default
- Android: browser prompts install natively; PWA storage is tied to the installing browser (clear site data in browser settings to reset)
- iOS: manual "Add to Home Screen" (install banner guides users)

### Not yet set up
- Native mobile builds (APK/IPA) — PWA covers casual use for now
- App store signing (Google Play $25 one-time, Apple $99/year)
- Microsoft Store ($19 one-time) — easiest store option for native Windows distribution; use `msix` pub package to build MSIX from `pubspec.yaml`, Microsoft handles code signing
