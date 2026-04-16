import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pensine/main.dart';

/// Takes store-listing screenshots on a fresh install (default workspaces).
///
/// Run with:
///   flutter test integration_test/screenshot_test.dart
///
/// On CI the workflow converts these into PNG files via the binding.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> takeScreenshot(String name) async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    await binding.takeScreenshot(name);
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

  /// Scrolls until [finder] is visible and tappable on screen, using drag
  /// gestures + pump() instead of scrollUntilVisible (which calls
  /// pumpAndSettle and hangs on continuous animations).
  Future<void> scrollTo(WidgetTester tester, Finder finder,
      {double delta = 200}) async {
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 30; i++) {
      await settle(tester, timeout: const Duration(seconds: 1));
      if (finder.evaluate().isNotEmpty) {
        // Check the widget is within the screen bounds
        final box =
            finder.evaluate().first.renderObject as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        final screenSize = tester.view.physicalSize /
            tester.view.devicePixelRatio;
        // 100px accounts for AppBar + status bar
        if (position.dy >= 100 &&
            position.dy + box.size.height <= screenSize.height - 50) {
          return;
        }
      }
      await tester.drag(scrollable, Offset(0, -delta));
      await tester.pump(const Duration(milliseconds: 300));
    }
    throw StateError('Could not scroll to find widget');
  }

  testWidgets('Store screenshots', (tester) async {
    await tester.pumpWidget(const PensineApp());
    await settle(tester);

    // 1 — Home screen with default workspaces
    await takeScreenshot('01_home');

    // 2 — Open "Getting Started" thoughts board (first board in Welcome)
    await tester.tap(find.text('Getting Started'));
    await settle(tester);
    // Wait for marbles to settle after physics
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot('02_thoughts');

    // Go back to home
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    // 3 — Open "Essentials" flashcards board (French Vocab workspace)
    await scrollTo(tester, find.text('Essentials'));
    await tester.tap(find.text('Essentials'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot('03_flashcards');

    // 4 — Flip all flashcards
    await tester.tap(find.byTooltip('Flip all'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await takeScreenshot('04_flashcards_flipped');

    // Go back to home
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    // 5 — Open "Pancakes" checklist board (Cooking Recipes workspace)
    await scrollTo(tester, find.text('Pancakes'));
    await tester.tap(find.text('Pancakes'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot('05_checklist');

    // Go back to home
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    // 6 — Open "Weekend" todo board (Welcome workspace)
    await scrollTo(tester, find.text('Weekend'), delta: -200);
    await tester.tap(find.text('Weekend'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot('06_todo');
  });
}
