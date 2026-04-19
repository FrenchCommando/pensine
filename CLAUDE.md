# Pensine

A fun, visual notes app with different board types (thoughts, to-do, flashcards, steps). Lofi vibes, gamified interactions.

## Stack

- Flutter / Dart
- Local storage only, no backend
- Multiplatform mono-repo (mobile-first)

## Conventions

- Incremental development, always documented
- Simple authoring, rich visual rendering
- Sharing via .pensine file export
- Default example workspaces and boards in `home_screen.dart` (`_defaults()`) — shown on first launch and after reset
- All dialogs must be scrollable (`SingleChildScrollView`) for small screens
- Never use `Spacer()` in `AlertDialog.actions` (causes dialog to expand on large screens)
- Project notes go in `NOTES.md` — keep it concise. When a topic grows beyond a few bullets, split it into its own `.md` file (see `DEPLOYMENT.md`, `PENSINE_FORMAT.md`) and add a pointer from `NOTES.md`.
