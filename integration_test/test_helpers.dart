import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pensine/widgets/marble_board.dart';

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
///
/// [resumePhysics] temporarily resumes marble physics during [hold] so marbles
/// settle into a natural position before the screenshot. Use this in screenshot
/// tests where physics is kept paused between shots to reduce emulator load.
/// Leave false in preview tests where physics runs continuously.
Future<void> openBoard(WidgetTester tester, String name,
    {double scrollDelta = 200,
    Duration hold = const Duration(seconds: 2),
    bool resumePhysics = false}) async {
  await scrollTo(tester, find.text(name), delta: scrollDelta);
  await tester.tap(find.text(name));
  await settle(tester);
  if (resumePhysics) debugPauseMarblePhysics = false;
  await tester.pump(hold);
  if (resumePhysics) debugPauseMarblePhysics = true;
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
