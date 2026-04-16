import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pensine/main.dart';

/// Walks through the app for ~30 seconds to produce a store-listing preview
/// video.  The CI workflow records the simulator/emulator screen while this
/// test runs.
///
/// Run with:
///   flutter test integration_test/preview_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps frames until no more are scheduled, or [timeout] elapses.
  Future<void> settle(WidgetTester tester,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final end = tester.binding.clock.now().add(timeout);
    do {
      await tester.pump(const Duration(milliseconds: 100));
    } while (tester.binding.hasScheduledFrame &&
        tester.binding.clock.now().isBefore(end));
  }

  Future<void> pause(WidgetTester tester, {int seconds = 3}) async {
    await tester.pump(Duration(seconds: seconds));
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder,
      {double delta = 200}) async {
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 30; i++) {
      await settle(tester, timeout: const Duration(seconds: 1));
      if (finder.evaluate().isNotEmpty) {
        final box =
            finder.evaluate().first.renderObject as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        final screenSize = tester.view.physicalSize /
            tester.view.devicePixelRatio;
        if (position.dy >= 0 &&
            position.dy + box.size.height <= screenSize.height) {
          return;
        }
      }
      await tester.drag(scrollable, Offset(0, -delta));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('Preview walkthrough', (tester) async {
    await tester.pumpWidget(const PensineApp());
    await settle(tester);
    await pause(tester); // linger on home screen

    // Open thoughts board
    await tester.tap(find.text('Getting Started'));
    await settle(tester);
    await pause(tester, seconds: 4); // show marbles settling

    // Back to home
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await pause(tester, seconds: 2);

    // Open flashcards
    await scrollTo(tester, find.text('Essentials'));
    await tester.tap(find.text('Essentials'));
    await settle(tester);
    await pause(tester);

    // Flip cards
    await tester.tap(find.byTooltip('Flip all'));
    await settle(tester);
    await pause(tester);

    // Back to home
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await pause(tester, seconds: 2);

    // Open checklist
    await scrollTo(tester, find.text('Pancakes'));
    await tester.tap(find.text('Pancakes'));
    await settle(tester);
    await pause(tester);

    // Back to home
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await pause(tester, seconds: 2);

    // Open todo
    await scrollTo(tester, find.text('Weekend'), delta: -200);
    await tester.tap(find.text('Weekend'));
    await settle(tester);
    await pause(tester, seconds: 4); // end on todo board
  });
}
