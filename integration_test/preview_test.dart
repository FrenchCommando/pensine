import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pensine/main.dart';

/// Drives the app through a walkthrough while the CI workflow records the
/// screen natively (adb screenrecord / simctl recordVideo). No screenshots
/// are captured from the test itself — the video comes from the host.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///       --target=integration_test/preview_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final end = tester.binding.clock.now().add(timeout);
    do {
      await tester.pump(const Duration(milliseconds: 100));
    } while (tester.binding.hasScheduledFrame &&
        tester.binding.clock.now().isBefore(end));
  }

  Future<void> linger(WidgetTester tester,
      {Duration duration = const Duration(seconds: 3)}) async {
    final end = tester.binding.clock.now().add(duration);
    while (tester.binding.clock.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder,
      {double delta = 200}) async {
    final scrollable = find.byType(Scrollable).first;
    final screenSize =
        tester.view.physicalSize / tester.view.devicePixelRatio;
    final midY = screenSize.height / 2;
    for (var i = 0; i < 50; i++) {
      await settle(tester, timeout: const Duration(seconds: 1));
      if (finder.evaluate().isNotEmpty) {
        final box = finder.evaluate().first.renderObject as RenderBox;
        final center = box.localToGlobal(
            Offset(box.size.width / 2, box.size.height / 2));
        if (center.dy > 120 && center.dy < screenSize.height - 50) {
          return;
        }
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

  testWidgets('Preview walkthrough', (tester) async {
    await tester.pumpWidget(const PensineApp());
    await settle(tester);
    await linger(tester);

    await tester.tap(find.text('Getting Started'));
    await settle(tester);
    await linger(tester, duration: const Duration(seconds: 4));

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await linger(tester, duration: const Duration(seconds: 2));

    await scrollTo(tester, find.text('Essentials'));
    await tester.tap(find.text('Essentials'));
    await settle(tester);
    await linger(tester);

    await tester.tap(find.byTooltip('Flip all'));
    await settle(tester);
    await linger(tester);

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await linger(tester, duration: const Duration(seconds: 2));

    await scrollTo(tester, find.text('Pancakes'));
    await tester.tap(find.text('Pancakes'));
    await settle(tester);
    await linger(tester);

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await linger(tester, duration: const Duration(seconds: 2));

    await scrollTo(tester, find.text('Weekend'), delta: -200);
    await tester.tap(find.text('Weekend'));
    await settle(tester);
    await linger(tester, duration: const Duration(seconds: 4));
  });
}
