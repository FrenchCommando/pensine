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

**Account:** Apple Developer — $99/year at developer.apple.com

**Requires macOS:** Xcode only runs on Mac. Options:
- Cheap used Mac Mini ($200-300) as a build/debug box
- Cloud Mac (MacStadium, AWS EC2 Mac instances)
- GitHub Actions macOS runners (free tier includes them) — realistic for building/shipping once set up, but initial setup and debugging signing issues is painful without a local Mac
- Flutter CI services (Codemagic, Bitrise) — have macOS runners with free tiers

**Signing setup:**
1. Set Development Team ID in Xcode project settings
2. Xcode handles provisioning profiles and certificates automatically with Apple account
3. For CI: use `fastlane match` or manual certificate injection via GitHub Secrets

**Build:** `flutter build ipa`

**Store listing requirements:**
- App name, description, category, bundle ID (`com.pensine.pensine`)
- Screenshots for multiple device sizes (6.7", 6.5", 5.5" iPhones, iPad)
- Privacy policy URL (required)
- Upload via Xcode Organizer or Transporter CLI
- Submit for review (usually 1-2 days)

**Recommendation:** Start with Android (fully doable from Windows), tackle iOS when Mac access is available.

## Microsoft Store

- $19 one-time developer account
- Use `msix` pub package to build MSIX from `pubspec.yaml`
- Microsoft handles code signing
- Easiest store option for native Windows distribution

## Shared requirements (all stores)
- Privacy policy page — host on GitHub Pages (e.g. `frenchcommando.github.io/pensine/privacy`)
- Screenshots / promotional graphics per platform
- Version bump in `pubspec.yaml` before each release
