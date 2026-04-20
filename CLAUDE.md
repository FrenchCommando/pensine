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
- **Dispose discipline** — Any `Disposable` owning a controller in a dialog must live in a `StatefulWidget` whose `State.dispose()` handles cleanup (see `_NewBoardDialog`, `_PromptNameDialog`, `_ItemDialog`). Do NOT use `.whenComplete(controller.dispose)` or `try/finally` around `await showDialog` — those race the route's exit transition and trigger "used after disposed" on heavy parent trees. `TextPainter`s in custom paint code must be disposed after their final `paint()`/`layout()`. Leak tracker (`test/flutter_test_config.dart`) fails CI on any undisposed `Disposable`.
- **Every bugfix / feature ships with a test** — unit/widget in `test/` for anything exercisable under `flutter_tester`; integration in `integration_test/smoke_test.dart` for anything needing real platform channels (real SharedPreferences, dart:html, Android/iOS native lifecycle). If a bug genuinely can't be observed by any tool, question whether it's a bug.
