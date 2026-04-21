# Pensine

A fun, visual notes app with different board types (thoughts, to-do, flashcards, steps). Lofi vibes, gamified interactions.

## Stack

- Flutter / Dart
- Local storage only, no backend
- Multiplatform mono-repo (mobile-first)

## Architecture

- **`BoardsController`** (`lib/controllers/boards_controller.dart`) — `ChangeNotifier` that owns `workspaces`, `boards`, `collapsed`, `loading` state plus all persistence calls. `HomeScreen` is a consumer; don't call `LocalStorage` directly from screens.
- **`applyBoardTap`** (`lib/behavior/board_tap.dart`) — pure tap state machine per `BoardType`. Returns a declarative `BoardTapOutcome` (changed / addLap / timer command / haptics). `BoardScreen` orchestrates side effects from the outcome. Adding a new board type: one case in the switch + metadata on `BoardType`.
- **`buildDefaults`** (`lib/data/defaults.dart`) — seed workspaces + boards for first launch and Reset. Pure data, no widgets.
- **Platform split** via conditional imports: `file_storage.dart` / `_stub.dart`, `board_io_native.dart` / `_web.dart`, `pending_import_native.dart` / `_web.dart`. Same pattern for any new platform-spanning feature.

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
- **Dual-rendered live values share one helper.** When the same live quantity (countdown remaining seconds, timer totals, etc.) is shown in two UI places at once, route both through a single pure helper — any discrepancy between them is very obvious on screen, and consistency matters more than which rounding/formatting convention is "correct". If the convention is ambiguous, surface the options to the user and let them pick; don't silently choose and don't invent reasons to flip the choice later.
