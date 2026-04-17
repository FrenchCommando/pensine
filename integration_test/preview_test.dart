import 'dart:developer';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pensine/main.dart';

import 'test_helpers.dart';

/// Drives the app through a walkthrough while the CI workflow records the
/// screen natively (adb screenrecord / simctl recordVideo). No screenshots
/// are captured from the test itself — the video comes from the host.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///       --target=integration_test/preview_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Preview walkthrough', (tester) async {
    log('pumpWidget');
    await tester.pumpWidget(const PensineApp());
    await settle(tester);
    await linger(tester);

    log('tap Getting Started');
    await tester.tap(find.text('Getting Started'));
    await settle(tester);
    await linger(tester, duration: const Duration(seconds: 4));

    log('tap Shake');
    await tester.tap(find.byTooltip('Shake'));
    await linger(tester, duration: const Duration(seconds: 3));

    log('tap Back (from thoughts)');
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await linger(tester, duration: const Duration(seconds: 2));

    log('openBoard Essentials');
    await openBoard(tester, 'Essentials', hold: const Duration(seconds: 3));

    log('tap Flip all');
    await tester.tap(find.byTooltip('Flip all'));
    await settle(tester);
    await linger(tester);

    log('tap Back (from flashcards)');
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await linger(tester, duration: const Duration(seconds: 2));

    log('openBoard Pancakes');
    await openBoard(tester, 'Pancakes', hold: const Duration(seconds: 3));

    log('tap Back (from checklist)');
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await linger(tester, duration: const Duration(seconds: 2));

    log('openBoard Weekend');
    await openBoard(tester, 'Weekend',
        scrollDelta: -200, hold: const Duration(seconds: 4));
    log('done');
  });
}
