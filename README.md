<p align="center">
  <img src="assets/app_icon.png" alt="Pensine logo" width="128" height="128">
</p>

# Pensine

[![CI](https://github.com/FrenchCommando/pensine/actions/workflows/ci.yml/badge.svg)](https://github.com/FrenchCommando/pensine/actions/workflows/ci.yml)
[![Screenshots](https://github.com/FrenchCommando/pensine/actions/workflows/screenshots.yml/badge.svg)](https://github.com/FrenchCommando/pensine/actions/workflows/screenshots.yml)
[![Deploy to GitHub Pages](https://github.com/FrenchCommando/pensine/actions/workflows/deploy.yml/badge.svg)](https://github.com/FrenchCommando/pensine/actions/workflows/deploy.yml)
[![Release](https://github.com/FrenchCommando/pensine/actions/workflows/release.yml/badge.svg)](https://github.com/FrenchCommando/pensine/actions/workflows/release.yml)

A fun, visual notes app where ideas float as marbles. Drag, fling, and tap your way through different board types — lofi vibes, gamified interactions, no backend required.

**Try it now:** [frenchcommando.github.io/pensine](https://frenchcommando.github.io/pensine/) · [Website](https://frenchcommando.github.io/pensine/site/)

**Android beta** — to install via Play Store:
- [Testers group](https://groups.google.com/g/pensine-testers) — join first (required for access)
- [Play Store](https://play.google.com/store/apps/details?id=com.frenchcommando.pensine) — install on Android
- [Web](https://play.google.com/apps/testing/com.frenchcommando.pensine) — enrol from any browser

Or sideload the [latest APK](https://github.com/FrenchCommando/pensine/releases/latest) — enable "Install unknown apps" for your browser when prompted.

**iOS beta (TestFlight):** [join the beta](https://testflight.apple.com/join/KDHvbWKH) — tap the link on iPhone/iPad; installs the TestFlight app if needed.

## Board Types

- **Thoughts** — free-form notes that expand on tap
- **To-do** — tap to catch in the net (mark done), reset to release all
- **Flashcards** — tap to flip, double-tap when correct (shrinks to net), grows on wrong answer
- **Steps** — sequential checklist with numbered marbles, one active at a time

## Workspaces

Boards are grouped into workspaces — collections of related boards (e.g. Cooking Recipes, French Vocab, Pilot Checklists). Create, rename, recolor, and reorder workspaces from the home screen. Export a whole workspace as a single `.pensine` file.

## Features

- Dark/light theme toggle
- Drag and fling marbles around the screen
- Shake button to scatter
- Per-board accent color (tints title, net, and icon)
- Color picker and size slider per item
- Reorder boards by long-press drag on the home screen
- Rename, duplicate, or change board type from the popup menu
- Swipe to delete with undo, or delete from menu with confirmation
- Export/import boards as `.pensine` files
- Installable as a PWA on mobile and desktop

## Stack

- Flutter / Dart
- Local storage only (no backend, no account)

## Development

```bash
flutter run -d chrome    # web
flutter run -d windows   # desktop
```

## Deployment

Web builds deploy automatically to GitHub Pages on every push to `main` via GitHub Actions. Installable as a PWA on mobile and desktop.

## License

All Rights Reserved. See [LICENSE](LICENSE).
