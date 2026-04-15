# Pensine

A fun, visual notes app where ideas float as marbles. Drag, fling, and tap your way through different board types — lofi vibes, gamified interactions, no backend required.

**Try it now:** [frenchcommando.github.io/pensine](https://frenchcommando.github.io/pensine/)

## Board Types

- **Thoughts** — free-form notes that expand on tap
- **To-do** — tap to catch in the net (mark done), reset to release all
- **Flashcards** — tap to flip, double-tap when correct (shrinks to net), grows on wrong answer
- **Steps** — sequential checklist with numbered marbles, one active at a time

## Features

- Dark/light theme toggle
- Drag and fling marbles around the screen
- Shake button to scatter
- Color picker and size slider per item
- Reorder boards by long-press drag on the home screen
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
