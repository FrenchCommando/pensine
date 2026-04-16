# App Store Deployment

## Current state
- App ID: `com.pensine.pensine` (both platforms)
- App icons: configured for all sizes via `flutter_launcher_icons`
- Version: defined in `pubspec.yaml`, currently `1.1.0+2`
- iOS deployment target: 13.0
- Android: uses Flutter default min/target SDK versions
- Android release signing: **not configured** (TODO in `build.gradle.kts`)
- iOS development team: **not configured** (needs Apple Developer account)

## Android (Google Play)

**Account:** Google Play Developer — $25 one-time at play.google.com/console

**Signing setup (one-time, do from Windows):**
1. Generate a keystore: `keytool -genkey -v -keystore ~/pensine-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pensine`
2. Create `android/key.properties` (gitignored!) with keystore path, password, alias
3. Configure `android/app/build.gradle.kts` to read `key.properties` for release signing
4. **Keep the keystore forever** — you can never change it for a published app

**Build:** `flutter build appbundle` (Google Play requires AAB, not APK)

**Store listing requirements:**
- App name, description, category
- At least 2 phone screenshots (optionally tablet/Chromebook)
- Content rating questionnaire (~5 min)
- Privacy policy URL (required even for local-only apps)
- Upload AAB and submit for review (first review takes a few days)

**CI/CD:** Can add a GitHub Actions workflow for Android builds. Keystore injected via GitHub Secrets.

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
- `.github/workflows/build-ios.yml` — builds iOS (no signing) on push to main
- Signing setup still needed: certificates + provisioning profiles via GitHub Secrets

**Signing setup (TODO):**
1. Create certificates and provisioning profiles in Apple Developer portal
2. Store as GitHub Secrets for CI injection
3. For CI: use `fastlane match` or manual certificate injection

**Build:** `flutter build ipa`

**Upload:** via Transporter CLI or `xcrun altool` in CI

## Microsoft Store

- $19 one-time developer account
- Use `msix` pub package to build MSIX from `pubspec.yaml`
- Microsoft handles code signing
- Easiest store option for native Windows distribution

## Screenshots

Automated via `.github/workflows/screenshots.yml` (manual trigger).

- Uses Flutter integration tests (`integration_test/screenshot_test.dart`)
- Captures 6 screens: home, thoughts board, flashcards (front + flipped), checklist, todo
- **iOS:** runs on iPhone 16 Pro Max + iPhone 16 Pro simulators in parallel (macOS runner)
- **Android:** runs on Pixel 7 emulator (Linux runner, requires KVM for hardware acceleration)
- Screenshots uploaded as downloadable CI artifacts (Actions tab > run > Artifacts)
- Download and upload manually to App Store Connect / Google Play Console

## Shared requirements (all stores)
- Privacy policy page — host on GitHub Pages (e.g. `frenchcommando.github.io/pensine/privacy`)
- Version bump in `pubspec.yaml` before each release
