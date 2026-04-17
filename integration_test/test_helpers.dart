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

/// Scrolls until [finder] is visible and tappable on screen, using drag
/// gestures + pump() instead of scrollUntilVisible (which calls
/// pumpAndSettle and hangs on continuous animations).
Future<void> scrollTo(WidgetTester tester, Finder finder,
    {double delta = 200}) async {
  final scrollable = find.byType(Scrollable).first;
  final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final midY = screenSize.height / 2;
  for (var i = 0; i < 50; i++) {
    await settle(tester, timeout: const Duration(seconds: 1));
    if (finder.evaluate().isNotEmpty) {
      final box = finder.evaluate().first.renderObject as RenderBox;
      final center = box
          .localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
      // Widget center is in the tappable area (between AppBar and bottom)
      if (center.dy > 120 && center.dy < screenSize.height - 50) {
        return;
      }
      // Widget is in the tree but not in the right zone — use smaller drags
      // to nudge it into view instead of overshooting.
      final nudge = (center.dy - midY).clamp(-80, 80).toDouble();
      await tester.drag(scrollable, Offset(0, -nudge));
      await tester.pump(const Duration(milliseconds: 200));
      continue;
    }
    await tester.drag(scrollable, Offset(0, -delta));
    await tester.pump(const Duration(milliseconds: 300));
  }
  throw StateError('Could not scroll to find widget');
}
