<p align="center">
  <img src="assets/app_icon.png" alt="Pensine logo" width="128" height="128">
</p>

<h1 align="center">Pensine 🫧</h1>

<p align="center">
  <em>A place for your thoughts.</em><br>
  Drag, fling, and tap your way through boards of floating marbles. Lofi vibes, gamified, no backend, no account.<br>
  <sub><em>Penser</em> = to think 🇫🇷</sub>
</p>

<p align="center">
  <a href="https://github.com/FrenchCommando/pensine/actions/workflows/ci.yml"><img src="https://github.com/FrenchCommando/pensine/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/FrenchCommando/pensine/actions/workflows/integration.yml"><img src="https://github.com/FrenchCommando/pensine/actions/workflows/integration.yml/badge.svg" alt="Integration"></a>
  <a href="https://github.com/FrenchCommando/pensine/actions/workflows/artifacts.yml"><img src="https://github.com/FrenchCommando/pensine/actions/workflows/artifacts.yml/badge.svg" alt="Artifacts"></a>
  <a href="https://github.com/FrenchCommando/pensine/actions/workflows/deploy.yml"><img src="https://github.com/FrenchCommando/pensine/actions/workflows/deploy.yml/badge.svg" alt="Deploy"></a>
  <a href="https://github.com/FrenchCommando/pensine/actions/workflows/release.yml"><img src="https://github.com/FrenchCommando/pensine/actions/workflows/release.yml/badge.svg" alt="Release"></a>
</p>

---

## 🚀 Grab it

<p align="center">
  <a href="https://frenchcommando.github.io/pensine/"><img src="https://img.shields.io/badge/Play_in_browser-5A0FC8?logo=pwa&logoColor=white&style=for-the-badge" alt="Play in browser"></a>
  &nbsp;
  <a href="https://apps.apple.com/app/pensine/id6762313502"><img src="https://img.shields.io/badge/App_Store-0D96F6?logo=apple&logoColor=white&style=for-the-badge" alt="App Store"></a>
  &nbsp;
  <a href="#-android--two-step-install"><img src="https://img.shields.io/badge/Android_(beta)-34A853?logo=googleplay&logoColor=white&style=for-the-badge" alt="Android (beta)"></a>
  &nbsp;
  <a href="https://github.com/FrenchCommando/pensine/releases/latest"><img src="https://img.shields.io/badge/Windows_installer-0078D6?logo=windows11&logoColor=white&style=for-the-badge" alt="Windows installer"></a>
  &nbsp;
  <a href="https://github.com/FrenchCommando/pensine/releases/latest"><img src="https://img.shields.io/badge/Linux_.deb_+_AppImage-E95420?logo=ubuntu&logoColor=white&style=for-the-badge" alt="Linux .deb + AppImage"></a>
</p>

<p align="center">
  <sub>🌐 Web works offline as a PWA · 🍎 iOS live on the App Store · 🤖 Android is in closed test — <a href="#-android--two-step-install">two-step install below</a> · 🪟 Windows 10 1809+ / 11 ARM64 · 🐧 Linux x86_64 (glibc 2.31+)</sub>
</p>

### 🧪 Beta + alternative paths

- 🍎 **iOS beta** — [TestFlight](https://testflight.apple.com/join/KDHvbWKH) for bleeding-edge builds before they hit the App Store
- 🪟 **Windows portable** — [zip from Releases](https://github.com/FrenchCommando/pensine/releases/latest): extract, run `pensine.exe`, leave no trace. Good for locked-down PCs or USB-stick installs.
- 🐧 **Linux AppImage** — single-file portable: `chmod +x pensine-*.AppImage && ./pensine-*.AppImage`. No install, no root, any glibc-2.31+ distro. Delete the file to remove.

<details>
<summary>💡 <strong>Windows heads-up</strong> — SmartScreen + uninstall notes</summary>

Both Windows artifacts are unsigned while Microsoft Store listing is pending — SmartScreen warns on first launch; click **More info → Run anyway**.

**Uninstall the installer build:** Settings → Apps → Pensine → Uninstall (or "Uninstall Pensine" in the Start Menu folder). Removes all installed files and the `.pensine` file association. Your boards live under `%APPDATA%\pensine\` and survive uninstall — delete that folder by hand for a clean wipe, or use the in-app **About → Reset** before uninstalling.

**Uninstall the portable zip:** just delete the extracted folder.

</details>

<details>
<summary>💡 <strong>Linux heads-up</strong> — .deb vs AppImage, uninstall</summary>

Two unsigned artifacts on every release:

- **`.deb`** (Debian / Ubuntu / Mint / Pop!_OS) — `sudo apt install ./pensine-*.deb`. Installs to `/usr/lib/pensine/`, adds a Start menu entry + `.pensine` file association. Uninstall with `sudo apt remove pensine`. apt will warn once about "untrusted origin" — expected, the .deb isn't GPG-signed.
- **AppImage** (any distro, glibc 2.31+) — single file, `chmod +x` and run. No install, no menu entry unless you run [AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher) or similar to register it. Uninstall = delete the file.

Your boards live in your XDG data directory (typically under `~/.local/share/`) and survive uninstall; use in-app **About → Reset** for a clean wipe.

</details>

## 🤖 Android — two-step install

Android ships through Google Play's **closed test** track, so the Play Store listing is hidden by default. You need to opt in before it shows up.

### Step 1 · Join the testers group

Sign up here with the Google account you'll use on your phone:

👉 **[groups.google.com/g/pensine-testers](https://groups.google.com/g/pensine-testers)**

Free, needs a Google login, approval is near-instant. This is the account gate — whichever Google account joins the group is the one that can see the Play listing.

### Step 2 · Pick an install path

| Route | What it looks like |
|---|---|
| 📱 **Play Store on the phone** | Open [this link](https://play.google.com/store/apps/details?id=com.frenchcommando.pensine) on your Android device (signed into the same Google account from Step 1). Install button appears normally. |
| 🌐 **Web enrol first** | Open [this link](https://play.google.com/apps/testing/com.frenchcommando.pensine) from any browser (even desktop) to flip the per-account opt-in flag. Then open Play Store on the phone and install as usual. |
| ⚡ **Sideload the APK** | Skip Play entirely. Grab the latest `.apk` from [Releases](https://github.com/FrenchCommando/pensine/releases/latest), open it on the phone, enable "Install unknown apps" for your browser when prompted. |

> ⚠️ **Sideload vs. Play are not interchangeable on the same device.** The sideloaded APK is signed with the upload key; the Play version is re-signed by Google. If you have one installed, Android will refuse the other with a signature-conflict error — uninstall first to switch.

Pensine hasn't been promoted to Google Play's production track yet. When it is, Step 1 goes away and the listing becomes a normal one-click install like the App Store.

---

## 🧩 Board types

Pick a flavor, drop your marbles in. Every board lives inside a workspace.

| | Board | What it does |
|---|---|---|
| 💭 | **Thoughts** | Free-form notes that expand on tap. Long-press to edit. |
| ✅ | **To-do** | Tap to catch in the net (done). Reset releases everything back into play. |
| 🎴 | **Flashcards** | Tap to flip. Tap again = wrong (grows + flips back). Double-tap = correct (shrinks to net). |
| 🪜 | **Steps** | Sequential checklist with numbered marbles, one active at a time. |
| ⏱️ | **Timer** | Steps + stopwatch overlay. Logs a lap every advance. |
| ⏳ | **Countdown** | Steps + per-step timer. Auto-advances when the clock hits zero. |

## 🗂️ Workspaces

Boards live in workspaces — collections of related boards (e.g. **Cooking Recipes**, **French Vocab**, **Pilot Checklists**). Create, rename, recolor, and reorder them from the home screen. Export a whole workspace as a single `.pensine` file.

## ✨ Features

- 🌓 Dark / light theme toggle
- 🫧 Drag and fling marbles around the screen
- 📳 Shake button to scatter everything
- 🎨 Per-board accent color (tints title, net, and icon)
- 🎨 Color picker and size slider per item
- 🔀 Reorder boards by long-press drag on the home screen
- 🏷️ Rename, duplicate, or change board type from the popup menu
- 🗑️ Swipe to delete with undo
- 📤 Export / import as `.pensine` files
- 📲 Installable as a PWA on mobile and desktop
- ⌨️ Full keyboard shortcuts on desktop / web

---

## 🛠️ Stack

- **Flutter / Dart** — one codebase, 6 targets
- **Local storage only** — no backend, no account, your boards never leave your device unless you export them

## 💻 Development

```bash
flutter run -d chrome    # web
flutter run -d windows   # desktop
flutter run -d macos     # desktop
```

Web builds deploy automatically to GitHub Pages on every push to `main`.

## 📄 License

All Rights Reserved. See [LICENSE](LICENSE).
