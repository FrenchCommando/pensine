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
- `shared_preferences` on web and mobile, `path_provider` + JSON file on desktop (see `lib/storage/local_storage.dart`).
  - Web: browser localStorage
  - Mobile: NSUserDefaults (iOS) / SharedPreferences (Android)
  - Desktop: JSON file in app support directory

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
- **All boards**: drag to fling, long-press empty space to add, shake button scatters marbles

## UI
- Dark/light theme toggle (persisted via `shared_preferences`), available on all screens
- About dialog accessible from all screens
- Marble/net sizes scale with screen size (responsive, no hardcoded pixel values)
- Text in marbles auto-shrinks to fit
- Color picker in add/edit dialogs

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

### CI
- `.github/workflows/ci.yml` — runs on push/PR to main: `flutter analyze`, `flutter test`, `flutter build web`

### CD
- `.github/workflows/deploy.yml` — deploys to GitHub Pages after CI succeeds on main (uses `workflow_run`)

### Not yet set up
- Release builds (APK/IPA artifacts on GitHub releases)
- App store signing
