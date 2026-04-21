import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hard-guard against running Windows integration tests on a developer
/// machine: dev builds and the installed Pensine share `%APPDATA%`,
/// `%TEMP%`, and the shared_preferences registry hive — local runs would
/// pollute the user's real workspaces and leak the test's `Integration
/// Test Workspace` board into them.
///
/// Other targets (chrome / android / ios) run sandboxed (browser storage,
/// emulator/simulator FS) and are safe locally, so the guard only fires
/// on Windows.
///
/// CI sets `CI=true` (GitHub Actions does this automatically). To override
/// for local debugging — accepting the data pollution — set `CI=true` in
/// the shell before `flutter drive`.
void requireCIOnWindows() {
  // `Platform` from `dart:io` throws `UnsupportedError` on web at runtime
  // (even though the import resolves at compile time). Chrome driver
  // builds this test, `main()` runs under the web engine, and without
  // the `kIsWeb` short-circuit `Platform.isWindows` throws, `main()`
  // never finishes, and `flutter drive` hangs until the job times out.
  // Web always runs sandboxed browser storage anyway — no data leak
  // concern — so the guard is a no-op there.
  if (kIsWeb) return;
  if (Platform.isWindows && Platform.environment['CI'] != 'true') {
    throw StateError(
      'Windows integration tests are CI-only: dev builds share user data '
      'with the installed app (%APPDATA%, %TEMP%, shared_preferences). '
      'Set CI=true in your shell to override locally.',
    );
  }
}

/// Pumps frames until no more are scheduled, or [timeout] elapses.
/// Unlike pumpAndSettle this won't throw on continuous animations.
Future<void> settle(WidgetTester tester,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final end = tester.binding.clock.now().add(timeout);
  do {
    await tester.pump(const Duration(milliseconds: 100));
  } while (tester.binding.hasScheduledFrame &&
      tester.binding.clock.now().isBefore(end));
}

/// Pumps frames for [duration] without exiting early. Used to hold a frame
/// on screen so the host-side recorder captures it.
Future<void> linger(WidgetTester tester,
    {Duration duration = const Duration(seconds: 3)}) async {
  final end = tester.binding.clock.now().add(duration);
  while (tester.binding.clock.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens a board by name: scroll to it, tap, settle, and hold a moment so
/// marble physics can reach a visually-stable state.
Future<void> openBoard(WidgetTester tester, String name,
    {double scrollDelta = 200,
    Duration hold = const Duration(seconds: 2)}) async {
  await scrollTo(tester, find.text(name), delta: scrollDelta);
  await tester.tap(find.text(name));
  await settle(tester);
  await tester.pump(hold);
}

/// Scrolls until [finder] is visible and tappable on screen, using drag
/// gestures + pump() instead of scrollUntilVisible (which calls
/// pumpAndSettle and hangs on continuous animations).
Future<void> scrollTo(WidgetTester tester, Finder finder,
    {double delta = 200}) async {
  final scrollable = find.byType(Scrollable).first;
  final scrollState = tester.state<ScrollableState>(scrollable);
  // Reset to top so the search always starts from a known position.
  // Without this, navigating back mid-list leaves us at the previous scroll
  // offset and a downward-only search misses items above it.
  scrollState.position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 100));
  for (var i = 0; i < 50; i++) {
    await settle(tester, timeout: const Duration(seconds: 1));
    if (finder.evaluate().isNotEmpty) {
      // tester.ensureVisible uses duration:zero (instant, no animation ticker)
      // so it won't hang under continuous marble-physics frames, unlike the
      // plain Scrollable.ensureVisible with a non-zero duration.
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    final before = scrollState.position.pixels;
    await tester.drag(scrollable, Offset(0, -delta));
    await tester.pump(const Duration(milliseconds: 300));
    if ((scrollState.position.pixels - before).abs() < 1) {
      // Drag had no effect — at the list edge, target is not in this list.
      throw StateError(
          'Reached scroll edge without finding widget (wrong direction?)');
    }
  }
  throw StateError('Could not scroll to find widget');
}
