import 'dart:io';
import 'package:flutter/material.dart';
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
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot(name);
  }

  testWidgets('Store screenshots', (tester) async {
    await tester.pumpWidget(const PensineApp());
    await tester.pumpAndSettle();

    // 1 — Home screen with default workspaces
    await takeScreenshot('01_home');

    // 2 — Open "Getting Started" thoughts board (first board in Welcome)
    await tester.tap(find.text('Getting Started'));
    await tester.pumpAndSettle();
    // Wait for marbles to settle after physics
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot('02_thoughts');

    // Go back to home
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // 3 — Open "Essentials" flashcards board (French Vocab workspace)
    // Scroll down to find it
    await tester.scrollUntilVisible(find.text('Essentials'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Essentials'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot('03_flashcards');

    // 4 — Flip all flashcards
    await tester.tap(find.byTooltip('Flip all'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await takeScreenshot('04_flashcards_flipped');

    // Go back to home
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // 5 — Open "Pancakes" checklist board (Cooking Recipes workspace)
    await tester.scrollUntilVisible(find.text('Pancakes'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pancakes'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot('05_checklist');

    // Go back to home
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // 6 — Open "Weekend" todo board (Welcome workspace)
    await tester.scrollUntilVisible(find.text('Weekend'), -200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekend'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot('06_todo');
  });
}
