import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pensine/main.dart';

import 'test_helpers.dart';

/// Takes store-listing screenshots on a fresh install (default workspaces).
///
/// Run with (via driver for file output):
///   flutter drive --driver=test_driver/integration_test.dart \
///       --target=integration_test/screenshot_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Trust scoped to exactly the cert the workflow minted for this run.
  // Cert bytes arrive as base64 via --dart-define; nothing checked in.
  final httpClient = () {
    const certB64 = String.fromEnvironment('SCREENSHOT_CERT_B64');
    if (certB64.isEmpty) return HttpClient();
    final ctx = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(base64Decode(certB64));
    return HttpClient(context: ctx);
  }();

  Future<void> takeScreenshot(String name) async {
    if (Platform.isAndroid) {
      // convertFlutterSurfaceToImage deadlocks on Android emulators. The host
      // workflow runs an HTTPS server that grabs frames via `adb screencap`;
      // we POST over the emulator's host alias 10.0.2.2 and wait for 200,
      // which means the PNG is written.
      const port = String.fromEnvironment('SCREENSHOT_PORT',
          defaultValue: '8765');
      final req = await httpClient
          .postUrl(Uri.parse('https://10.0.2.2:$port/screenshot/$name'));
      final res = await req.close();
      await res.drain();
      if (res.statusCode != 200) {
        throw StateError(
            'Screenshot capture failed for "$name": HTTP ${res.statusCode}');
      }
      return;
    }
    await binding.takeScreenshot(name);
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
