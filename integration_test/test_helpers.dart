import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
  for (var i = 0; i < 50; i++) {
    await settle(tester, timeout: const Duration(seconds: 1));
    if (finder.evaluate().isNotEmpty) {
      // Hand off to the framework — handles centering, partial clipping,
      // and edge-of-list cases without manual viewport math.
      await Scrollable.ensureVisible(
        finder.evaluate().first,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
      await settle(tester, timeout: const Duration(seconds: 1));
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
