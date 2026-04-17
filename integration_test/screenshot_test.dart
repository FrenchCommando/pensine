import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pensine/main.dart';
import 'package:pensine/widgets/marble_board.dart';

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

  // Both platforms now capture via a host-side server:
  //   Android — HTTPS + cert pinning over 10.0.2.2 (emulator → host).
  //   iOS     — plain HTTP over 127.0.0.1 (sim shares host loopback).
  // iOS started hanging in `binding.takeScreenshot` because the marble ticker
  // calls setState every frame, so Flutter's screenshot path never sees idle.
  // Host-driven capture bypasses that entirely.
  const host = String.fromEnvironment('SCREENSHOT_HOST');

  Future<void> takeScreenshot(WidgetTester tester, String name) async {
    debugPauseMarblePhysics = true;
    try {
      if (host.isNotEmpty) {
        final req =
            await httpClient.postUrl(Uri.parse('$host/screenshot/$name'));
        final res = await req.close();
        await res.drain();
        if (res.statusCode != 200) {
          throw StateError(
              'Screenshot capture failed for "$name": HTTP ${res.statusCode}');
        }
        return;
      }
      await binding.takeScreenshot(name);
    } finally {
      debugPauseMarblePhysics = false;
    }
  }

  testWidgets('Store screenshots', (tester) async {
    await tester.pumpWidget(const PensineApp());
    await settle(tester);

    await takeScreenshot(tester, '01_home');

    await tester.tap(find.text('Getting Started'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await takeScreenshot(tester, '02_thoughts');

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    await openBoard(tester, 'Essentials');
    await takeScreenshot(tester, '03_flashcards');

    await tester.tap(find.byTooltip('Flip all'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await takeScreenshot(tester, '04_flashcards_flipped');

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    await openBoard(tester, 'Pancakes');
    await takeScreenshot(tester, '05_checklist');

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    await openBoard(tester, 'Weekend', scrollDelta: -200);
    await takeScreenshot(tester, '06_todo');
  });
}
