# Notes

## Windows Setup
- Flutter requires Developer Mode enabled (`ms-settings:developers`) for symlink support when building with plugins.

## Known Issues
- `Failed to update ui::AXTree` errors on Windows — known Flutter bug with accessibility bridge during rapid widget updates (60fps ticker). Harmless, ignore.

## Web Deployment
- GitHub Pages: `https://frenchcommando.github.io/pensine/`
- Deployed via `.github/workflows/deploy.yml` on every push to `main`
- Requires GitHub repo Settings → Pages → Source set to **GitHub Actions**
- Uses `--base-href "/pensine/"` for correct asset paths

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
- GitHub Actions workflow in `.github/workflows/ci.yml`
- Runs on push/PR to main: `flutter analyze`, `flutter test`, `flutter build web`

### Not yet set up
- Release builds (APK/IPA artifacts on GitHub releases)
- App store signing
