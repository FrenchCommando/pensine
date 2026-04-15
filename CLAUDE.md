# Pensine

A fun, visual notes app with different board types (thoughts, to-do, flashcards). Lofi vibes, gamified interactions.

## Stack

- Flutter / Dart
- Local storage only, no backend
- Multiplatform mono-repo (mobile-first)

## Conventions

- Incremental development, always documented
- Simple authoring, rich visual rendering
- Sharing via .pensine file export
- Default example boards in `home_screen.dart` (`_defaultBoards()`) — shown on first launch and after reset
- All dialogs must be scrollable (`SingleChildScrollView`) for small screens
- Project notes go in `NOTES.md`
