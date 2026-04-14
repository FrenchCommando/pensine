# Notes

## Windows Setup
- Flutter requires Developer Mode enabled (`ms-settings:developers`) for symlink support when building with plugins.

## Known Issues
- `Failed to update ui::AXTree` errors on Windows — known Flutter bug with accessibility bridge during rapid widget updates (60fps ticker). Harmless, ignore.

## Web Deployment
- Current storage uses `path_provider` + JSON file, which doesn't work on web (no filesystem).
- Before web deploy, need to switch to `shared_preferences` or similar (handles localStorage/IndexedDB automatically).

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

### Not yet set up
- CI/CD pipeline
- Web deployment (GitHub Pages)
- App store signing

## Next Steps
- Switch storage to `shared_preferences` for cross-platform support
- Build for web + GitHub Pages
